
require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-imy-bin/helpers/local/local_framework_builder'
require 'cocoapods-imy-bin/helpers/local/local_library_builder'
require 'cocoapods-imy-bin/helpers/local/local_build_helper'
require 'cocoapods-imy-bin/helpers/spec_source_creator'
require 'cocoapods-imy-bin/config/config_builder'

module Pod
  class Command
    class Bin < Command
      class Local < Bin
        self.summary = '根据podfile中信息 将本地已存在的组件静态包 归档，需要归档的组件由外部传入'
        self.description = <<-DESC
          根据podfile中信息 将本地已存在的组件静态包 归档，需要归档的组件由外部传入
          仅支持 iOS 平台
          此静态 framework/.a 不包含依赖组件的 symbol

          一个用ccache，一个是cocoapods-imy-bin插件支持下的，
          拿xcodebuild生成的中间构建产物，如生成的 libIMYYQHome.a，利用cocoapods-imy-bin 制作成二进制静态库，保存起来。
          下次pod update 工程时，在pod update时去捞已经生成的二进制组件打包。这样可以大大减少编译时间

          制作流程:
          每次pod update 时记录无二进制组件的库，build完后，自动制作缺失二进制组件库。
          如果pod update 时无二进制组件的库，采用源码编译，源码编译同时有ccache缓存支持，也能加快速度
        DESC

        def self.options
          [
            ['--no-clean', '保留构建中间产物'],
            ['--framework-output', '输出framework文件'],
            ['--no-zip', '不压缩静态 framework 为 zip'],
            ['--make-binary-specs', '需要制作spec集合'],
            ['--env', "该组件上传的环境 %w[dev debug_iphoneos release_iphoneos]"]
          ].concat(Pod::Command::Gen.options).concat(super).uniq
        end

        def initialize(argv)
          @env = argv.option('env') || 'dev'
          CBin.config.set_configuration_env(@env)
          UI.warn "====== cocoapods-imy-bin #{CBin::VERSION} 版本 ======== \n "
          UI.warn "======  #{@env} 环境 ======== "


          @make_binary_specs = argv.option('make-binary-specs') || []
          @framework_output = argv.flag?('framework-output', false)
          @clean = argv.flag?('no-clean', true)
          @zip = argv.flag?('zip', true)
          @sources = argv.option('sources') || []
          @platform = Platform.new(:ios)

          @target_name = CBin::Config::Builder.instance.target_name
          @local_build_dir_name = CBin::Config::Builder.instance.xcode_build_name
          @local_build_dir = CBin::Config::Builder.instance.xcode_build_dir

          @framework_path
          super
        end

        def run
          # 清除之前的缓存
          # temp = File.join(@local_build_dir, @platform.to_s)
          # FileUtils.rm_r(temp) if File.exist? temp
          # if File.exist?(CBin::Config::Builder.instance.zip_dir)
          #   FileUtils.rm_rf(Dir.glob("#{CBin::Config::Builder.instance.zip_dir}/*"))
          # end

          sources_spec = []
          Dir.chdir(CBin::Config::Builder.instance.local_psec_dir) do
            spec_files = Dir.glob(%w[*.json *.podspec])
            spec_files.each do |file|
              spec = Pod::Specification.from_file(file)
              sources_spec << spec
            end
          end

          build(sources_spec)
        end

        def build(make_binary_specs)
          # 如果没要求，就清空依赖库数据
          sources_sepc = []
          make_binary_specs.uniq.each do |spec|
            next if spec.name.include?('/')
            next if spec.name == @target_name
            #过滤白名单
            next if CBin::Config::Builder.instance.white_pod_list.include?(spec.name)
            #过滤 git
            if spec.source[:git] && spec.source[:git]
              spec_git = spec.source[:git]
              spec_git_res = false
              CBin::Config::Builder.instance.ignore_git_list.each do |ignore_git|
                spec_git_res = spec_git.include?(ignore_git)
                break if spec_git_res
              end
              next if spec_git_res
            end
            UI.warn "#{spec.name}.podspec 带有 vendored_frameworks 字段，请检查是否有效！！！" if spec.attributes_hash['vendored_frameworks']
            next if spec.attributes_hash['vendored_frameworks'] && @target_name != spec.name #过滤带有vendored_frameworks的
            next if (spec.attributes_hash['ios'] && spec.attributes_hash['ios']['vendored_frameworks'])  #过滤带有vendored_frameworks的
            #获取没有制作二进制版本的spec集合

            next unless library_exist(spec)

            # 获取没有制作二进制版本的spec集合
            sources_sepc << spec
          end

          fail_build_specs = []
          sources_sepc.uniq.each do |spec|
            begin
              builder = CBin::LocalBuild::Helper.new(spec,
                                                     @platform,
                                                     @framework_output,
                                                     @zip,
                                                     @clean,
                                                     @target_name,
                                                     @local_build_dir_name,
                                                     @local_build_dir)
              builder.build
              CBin::Upload::Helper.new(spec, @code_dependencies, @sources).upload
            rescue StandardError
              fail_build_specs << spec
            end
          end

          if fail_build_specs.any?
            fail_build_specs.uniq.each do |spec|
              UI.warn "【#{spec.name} | #{spec.version}】组件二进制版本编译失败 ."
            end
          end

          success_specs = sources_sepc - fail_build_specs
          if success_specs.any?
            success_specs.uniq.each do |spec|
              UI.warn " =======【 #{spec.name} | #{spec.version} 】二进制组件制作完成 ！！！"
            end
          end
          # pod repo update
          UI.section("\nUpdating Spec Repositories\n".yellow) do
            Pod::Command::Bin::Repo::Update.new(CLAide::ARGV.new([])).run
          end
        end

        private

        def library_exist(spec)
          File.exist?(File.join(@local_build_dir, "lib#{spec.name}.a")) || is_framework(spec)
        end
        # 使用了user_framework 会有#{@spec.name}.framework
        # 未使用的 需要判断文件
        def is_framework(spec)
          res = File.exist?(File.join(@local_build_dir, "#{spec.name}.framework"))
          unless res
            res = File.exist?(File.join(CBin::Config::Builder.instance.xcode_BuildProductsPath_dir, "#{spec.name}","Swift Compatibility Header"))
          end
          res
        end

      end
    end
  end
end

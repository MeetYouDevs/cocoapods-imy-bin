require 'cocoapods'
require 'cocoapods/target/pod_target'

module Pod
  class Command
    class Bin < Command
      class Dup < Bin
        self.summary = '在Podfile目录下，查找Pods下同名资源名'

        self.description = <<-DESC
          在Podfile目录下，查找Pods下同名资源名
        DESC

        self.arguments = [
            CLAide::Argument.new('NAME', false)
        ]
        def self.options
          [
              ['--all-clean', '删除所有已经下载的源码'],
              ['--clean', '删除所有指定下载的源码'],
              ['--list', '展示所有一级下载的源码以及其大小'],
              ['--source', '源码路径，本地路径,会去自动链接本地源码']
          ]
        end

        def initialize(argv)
          @codeSource =  argv.option('source') || nil

          @config = Pod::Config.instance

          super
        end


        def run
          target_definition = Pod::Config.instance.podfile.target_definition_list[1]

          user_build_configurations = target_definition.build_configurations || Target::DEFAULT_BUILD_CONFIGURATIONS
          aggregateTarget = AggregateTarget.new(Pod::Config.instance.sandbox,
                                                target_definition.uses_frameworks?,
                                                user_build_configurations ,
                                                nil,
                                                target_definition.platform,
                                                target_definition,
                                                Pod::Config.instance.installation_root,
                                                nil,
                                                nil ,
                                                user_build_configurations)
          input_file = aggregateTarget.copy_resources_script_path
          output_pods_suffix_txt = File.join(Pod::Config.instance.project_root,"output_pods_suffix.txt")
          output_pods_uniq_txt = File.join(Pod::Config.instance.project_root,"output_pods_uniq.txt")
          ignore_array = ["bundle","mp3"]
          resources_path = File.join(File.dirname(File.dirname(File.dirname(__FILE__))),"resources")
          shell_file = File.join(resources_path,"Pods-check-deduplication-resources.sh")
          #ruby 调用shell 文件、命令传入
          # stdout shell 脚本输出的文本
          # status 退出的状态
          stdout, status = Open3.capture2('/bin/sh',
                                          "#{shell_file}",
                                          "#{input_file}",
                                          "#{output_pods_suffix_txt}",
                                          "#{output_pods_uniq_txt}",
                                          "#{ignore_array}")

          #重复资源 抛出异常
          if status.to_i != 0
            raise "由于权限不足，请手动创建 后重试"
          else #重复资源，警告
            raise "由于权限不足，请手动创建 后重试"

          end
        end


      end
    end
  end
end

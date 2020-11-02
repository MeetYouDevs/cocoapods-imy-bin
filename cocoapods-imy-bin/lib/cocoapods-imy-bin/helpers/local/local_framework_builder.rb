

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/helpers/local/local_framework'
require 'English'
require 'cocoapods-imy-bin/config/config_builder'
require 'shellwords'

module CBin
  class LocalFramework
    class Builder
      include Pod
#Debug下还待完成
      def initialize(spec, file_accessor, platform, local_build_dir_name, local_build_dir, is_library = true, framework_BuildProductsPath = "")
        @spec = spec
        @file_accessor = file_accessor
        @platform = platform
        @local_build_dir_name = local_build_dir_name
        @local_build_dir = local_build_dir
        @is_library = is_library
        @framework_BuildProductsPath = framework_BuildProductsPath
      end

      def create
        begin
          #如果是.a 文件， 或者 swift下，是.a文件的
          if @is_library || (!@is_library && @framework_BuildProductsPath != framework_name)

            UI.section("Building static library #{@spec}") do
              output = framework.versions_path + Pathname.new(@spec.name)
              build_static_library_for_ios(output)
              res = copy_headers
              # maybe fails for copy_headers
              if res
                copy_resources
                cp_to_source_dir
              else
                FileUtils.remove_dir(framework.fwk_path) if File.exist?(framework.fwk_path)
                return nil
              end
            end

          else
            UI.section("Building static framework #{@spec}") do
              output = File.join(CBin::Config::Builder.instance.zip_dir,"#{@spec.name}.framework")
              build_static_framework_for_ios(output)
            end
          end

        rescue StandardError
          UI.warn "【#{spec.name} | #{spec.version}】组件二进制版本组装失败 ."
        end

        framework
      end

      private

      def cp_to_source_dir
        # 删除Versions 软链接
        framework.remove_current_version if CBin::Build::Utils.is_swift_module(@spec)

        target_dir = File.join(CBin::Config::Builder.instance.root_dir,CBin::Config::Builder.instance.framework_file(@spec))
        FileUtils.rm_rf(target_dir) if File.exist?(target_dir)

        zip_dir = CBin::Config::Builder.instance.zip_dir
        FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

        `cp -fa #{@platform}/#{CBin::Config::Builder.instance.framework_name(@spec)} #{target_dir}`
      end


      def copy_headers
        #by slj 如果没有头文件，去 "Headers/Public"拿
        # if public_headers.empty?
        Dir.chdir(File.join(Pod::Config.instance.installation_root,'Pods')) do

          if File.exist?("./Headers/Public/#{@spec.name}")
            #走 podsepc中的public_headers
            public_headers = Array.new

            Dir.chdir("./Headers/Public/#{@spec.name}") do
              headers = Dir.glob('*.h')
              headers.each do |h|
                public_headers << Pathname.new(File.join(Dir.pwd,h))
              end
            end

            UI.message "Copying public headers #{public_headers.map(&:basename).map(&:to_s)}"

            public_headers.each do |h|
              `ditto #{h} #{framework.headers_path}/#{h.basename}`
            end

            # If custom 'module_map' is specified add it to the framework distribution
            # otherwise check if a header exists that is equal to 'spec.name', if so
            # create a default 'module_map' one using it.
            if !@spec.module_map.nil?
              module_map_file = @file_accessor.module_map
              if Pathname(module_map_file).exist?
                module_map = File.read(module_map_file)
              end
            elsif public_headers.map(&:basename).map(&:to_s).include?("#{@spec.name}-umbrella.h")
              module_map = <<-MAP
          framework module #{@spec.name} {
            umbrella header "#{@spec.name}-umbrella.h"

            export *
            module * { export * }
          }
              MAP
            end

            unless module_map.nil?
              UI.message "Writing module map #{module_map}"
              unless framework.module_map_path.exist?
                framework.module_map_path.mkpath
              end
              File.write("#{framework.module_map_path}/module.modulemap", module_map)

              # unless framework.swift_module_path.exist?
              #   framework.swift_module_path.mkpath
              # end
              # DO BuildProductsPath  swiftModule拷贝到 framework.swift_module_path
              swiftmodule_path = File.join(@framework_BuildProductsPath, "#{@spec.name}.swiftmodule")
              if File.directory?(swiftmodule_path)
                FileUtils.cp_r("#{swiftmodule_path}/.", framework.swift_module_path)
              end
              swift_Compatibility_Header = "#{@framework_BuildProductsPath}/Swift\ Compatibility\ Header/#{@spec.name}-Swift.h"
              FileUtils.cp(swift_Compatibility_Header,framework.headers_path) if File.exist?(swift_Compatibility_Header)
              info_plist_file = File.join(File.dirname(File.dirname(__FILE__)),"info.plist")
              FileUtils.cp(info_plist_file,framework.fwk_path)
            end
          else
            UI.warn "== Headers/Public/#{@spec.name} no exist"
            return false
          end

        end
        return true
      end

      def copy_resources


        Dir.chdir(Pod::Config.instance.sandbox_root) do

          bundles = Dir.glob('./build/*.bundle')

          bundle_names = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
            consumer = spec.consumer(@platform)
            consumer.resource_bundles.keys +
                consumer.resources.map do |r|
                  File.basename(r, '.bundle') if File.extname(r) == 'bundle'
                end
          end.compact.uniq

          bundles.select! do |bundle|
            bundle_name = File.basename(bundle, '.bundle')
            bundle_names.include?(bundle_name)
          end

          if bundles.count > 0
            UI.message "Copying bundle files #{bundles}"
            bundle_files = bundles.join(' ')
            `cp -rp #{bundle_files} #{framework.resources_path} 2>&1`
          end

          real_source_dir = @spec.name
          resources = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
            expand_paths(real_source_dir, spec.consumer(@platform).resources)
          end.compact.uniq

          if (resources.count == 0 || (resources.count == 1 && resources[0].count == 0)) && bundles.count == 0
            framework.delete_resources
            return
          end

          if resources.count > 0
            #把 路径转义。 避免空格情况下拷贝失败
            escape_resource = []
            resources.each do |source|
              escape_resource << Shellwords.join(source)
            end
            UI.message "Copying resources #{escape_resource}"
            `cp -rp #{escape_resource.join(' ')} #{framework.resources_path}`
          end

        end

      end


      def build_static_library_for_ios(output)
        `cp -rp  #{library_name} #{output}`
      end

      def build_static_framework_for_ios(output)
        FileUtils.cp_r(framework_name, output)
      end

      def library_name
        File.join(@local_build_dir, "lib#{@spec.name}.a")
      end

      def framework_name
        File.join(@local_build_dir, "#{@spec.name}.framework")
      end

      def expand_paths(source_dir, path_specs)
        path_specs.map do |path_spec|
          Dir.glob(File.join(source_dir, path_spec))
        end
      end

      def framework
        @framework ||= begin
          framework = CBin::LocalFramework.new(@spec.name, @platform.name.to_s,@local_build_dir)
          framework.make
          framework
        end
      end

    end
  end
end

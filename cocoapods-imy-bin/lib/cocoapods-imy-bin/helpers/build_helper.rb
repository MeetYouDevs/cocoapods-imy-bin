# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-imy-bin/helpers/framework_builder'
require 'cocoapods-imy-bin/helpers/library_builder'
require 'cocoapods-imy-bin/config/config_builder'

module CBin
  class Build
    class Helper
      include Pod
#class var
      @@build_defines = ""
#Debug下还待完成
      def initialize(spec,
                     platform,
                     framework_output,
                     zip,
                     rootSpec,
                     skip_archive = false,
                     build_model="Release")
        @spec = spec
        @platform = platform
        @build_model = build_model
        @rootSpec = rootSpec
        @isRootSpec = rootSpec.name == spec.name
        @skip_archive = skip_archive
        @framework_output = framework_output
        @zip = zip

        @framework_path
      end

      def build
        UI.section("Building static framework #{@spec}") do

          build_static_framework
          unless @skip_archive
            unless  CBin::Build::Utils.is_framework(@spec)
              build_static_library
              zip_static_library
            else
              zip_static_framework
            end
          end

        end

      end

      def build_static_framework
        source_dir = Dir.pwd
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::Framework::Builder.new(@spec, file_accessor, @platform, source_dir, @isRootSpec, @build_model )
          @@build_defines = builder.build if @isRootSpec
          begin
            @framework_path = builder.lipo_build(@@build_defines) unless @skip_archive
          rescue
            @skip_archive = true
          end
        end
      end

      def build_static_library
        source_dir = zip_dir
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::Library::Builder.new(@spec, file_accessor, @platform, source_dir,@framework_path)
          builder.build
        end
      end

      def zip_static_framework
        Dir.chdir(File.join(workspace_directory,@framework_path.root_path)) do
          output_name =  File.join(zip_dir, framework_name_zip)
          unless File.exist?(framework_name)
            UI.puts "没有需要压缩的 framework 文件：#{framework_name}"
            return
          end

          UI.puts "Compressing #{framework_name} into #{output_name}"
          `zip --symlinks -r #{output_name} #{framework_name}`
        end
      end

      def zip_static_library
        Dir.chdir(zip_dir) do
          output_library = "#{library_name}.zip"
          unless File.exist?(library_name)
            raise Informative, "没有需要压缩的 library 文件：#{library_name}"
          end

          UI.puts "Compressing #{library_name} into #{output_library}"

          `zip --symlinks -r #{output_library} #{library_name}`
        end

      end


      def clean_workspace
        UI.puts 'Cleaning workspace'

        FileUtils.rm_rf(gen_name)
        Dir.chdir(zip_dir) do
          FileUtils.rm_rf(framework_name) if @zip
          FileUtils.rm_rf(library_name)
          FileUtils.rm_rf(framework_name) unless @framework_output
          FileUtils.rm_rf("#{framework_name}.zip") unless @framework_output
        end
      end

      def framework_name
        CBin::Config::Builder.instance.framework_name(@spec)
      end

      def framework_name_zip
        CBin::Config::Builder.instance.framework_name_version(@spec) + ".zip"
      end

      def library_name
        CBin::Config::Builder.instance.library_name(@spec)
      end

      def workspace_directory
        File.expand_path("#{gen_name}/#{@rootSpec.name}")
      end

      def zip_dir
        CBin::Config::Builder.instance.zip_dir
      end

      def gen_name
        CBin::Config::Builder.instance.gen_dir
      end


      def spec_file
        @spec_file ||= begin
                         if @podspec
                           find_spec_file(@podspec)
                         else
                           if code_spec_files.empty?
                             raise Informative, '当前目录下没有找到可用源码 podspec.'
                           end

                           spec_file = code_spec_files.first
                           spec_file
                         end
                       end
      end

    end
  end
end

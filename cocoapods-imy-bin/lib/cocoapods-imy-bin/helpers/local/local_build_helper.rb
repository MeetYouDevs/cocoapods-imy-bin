

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-imy-bin/helpers/framework_builder'
require 'cocoapods-imy-bin/helpers/library_builder'
require 'cocoapods-imy-bin/config/config_builder'

module CBin
  class LocalBuild
    class Helper
      include Pod
#class var
      @@build_defines = ""
#Debug下还待完成
      def initialize(spec,
                     platform,
                     framework_output,
                     zip,
                     clean,
                     target_name,
                     local_build_dir_name,
                     local_build_dir)
        @spec = spec
        @target_name = target_name
        @platform = platform

        @framework_output = framework_output
        @zip = zip
        @local_build_dir_name = local_build_dir_name
        @local_build_dir = local_build_dir
        @clean = clean
        @framework_path
      end

      def build
        UI.section("Building static framework #{@spec}") do

          build_static_framework
          build_static_library
          zip_static_framework if @zip &&= @framework_output
          zip_static_library

          clean_workspace if @clean
        end

      end

      def build_static_framework
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::LocalFramework::Builder.new(@spec, file_accessor, @platform, @local_build_dir_name,@local_build_dir)
          @framework_path = builder.create
        end
      end

      def build_static_library
        source_dir = zip_dir
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::LocalLibrary::Builder.new(@spec, file_accessor, @platform, source_dir,@framework_path)
          builder.build
        end
      end

      def zip_static_framework
        Dir.chdir(zip_dir) do
          output_name = "#{framework_name}.zip"
          unless File.exist?(framework_name)
            raise Informative, "没有需要压缩的 framework 文件：#{framework_name}"
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

      def library_name
        CBin::Config::Builder.instance.library_name(@spec)
      end

      def workspace_directory
        @local_build_dir
      end

      def zip_dir
        CBin::Config::Builder.instance.zip_dir
      end

      def gen_name
        CBin::Config::Builder.instance.gen_name
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

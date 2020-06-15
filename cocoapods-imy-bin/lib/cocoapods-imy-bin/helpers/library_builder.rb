
# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/helpers/framework.rb'
require 'cocoapods-imy-bin/helpers/library.rb'

require 'English'

module CBin
  class Library
    class Builder
      include Pod

      def initialize(spec, file_accessor, platform, source_dir,framework_path)
        @spec = spec
        @source_dir = source_dir
        @file_accessor = file_accessor
        @platform = platform
        @framework = framework_path
        @source_files = "#{@source_dir}/#{library.name_path}"
        @source_zip_file = "#{@source_files}.zip"
      end

      def build
        UI.section("Building static library #{@spec}") do

          clean_source_dir

          copy_headers
          copy_library
          copy_resources

          cp_to_source_dir
        end
      end

      private

      def clean_source_dir
        FileUtils.rm_rf(@source_files) if File.exist?(@source_files)
        FileUtils.rm_rf(@source_zip_file) if File.exist?(@source_zip_file)
      end

      def cp_to_source_dir
        target_dir = library.versions_path
        dest_file = "#{@source_dir}/#{library.name_path}"
        FileUtils.rm_rf(dest_file) if File.exist?(dest_file)

        `cp -fa #{target_dir} #{dest_file}/`
      end

      def copy_headers
        FileUtils.cp_r(framework.headers_path,library.versions_path) if File.exist?(framework.headers_path)
      end

      def copy_library
        src_file = "#{framework.versions_path}/#{@spec.name}"
        unless File.exist?(src_file)
          raise Informative, "framework没有文件：#{src_file}"
        end

        dest_file = "#{library.versions_path}/#{@spec.name}"
        rename_dest_file = "#{library.versions_path}/lib#{@spec.name}.a"
        FileUtils.cp_r(src_file,dest_file)
        File.rename(dest_file, rename_dest_file ) if File.exist?(dest_file)
      end

      def copy_resources
        FileUtils.cp_r(framework.resources_path,library.versions_path) if File.exist?(framework.resources_path)
      end


      def framework
        @framework ||= begin
                        framework = Framework.new(@spec.name, @platform.name.to_s)
                        framework.make
                        framework
                       end
      end

      def library
        @library ||= begin
                       library = Library.new(@spec.name, @platform.name.to_s,@spec.version)
                       library.make
                       library
                     end
      end
    end
  end
end

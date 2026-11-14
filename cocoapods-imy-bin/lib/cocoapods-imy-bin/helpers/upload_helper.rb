

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-imy-bin/helpers/framework_builder'
require 'cocoapods-imy-bin/helpers/library_builder'
require 'cocoapods-imy-bin/helpers/sources_helper'
require 'cocoapods-imy-bin/command/bin/spec/push'
require 'open3'

module CBin
  class Upload
    class Helper
      include CBin::SourcesHelper

      def initialize(spec,code_dependencies,sources, xcframework: false)
        @spec = spec
        @code_dependencies = code_dependencies
        @sources = sources
        @xcframework = xcframework
      end

      def upload
        Dir.chdir(CBin::Config::Builder.instance.root_dir) do
          # 创建binary-template.podsepc
          # 上传二进制文件
          # 上传二进制 podspec
          res_zip = curl_zip
          if res_zip
            filename = spec_creator
            push_binary_repo(filename)
          end
          res_zip
        end
      end

      def spec_creator
        spec_creator = CBin::SpecificationSource::Creator.new(@spec, 'ios', xcframework: @xcframework)
        spec_creator.create
        spec_creator.write_spec_file
        spec_creator.filename
      end

      #推送二进制
      # curl http://ci.xxx:9192/frameworks -F "name=IMYFoundation" -F "version=7.7.4.2" -F "annotate=IMYFoundation_7.7.4.2_log" -F "file=@bin-zip/bin_IMYFoundation_7.7.4.2.zip"
      def curl_zip
        if @xcframework
          zip_file = CBin::Config::Builder.instance.xcframework_zip_file(@spec)
          return upload_zip(zip_file)
        end
        zip_file = "#{CBin::Config::Builder.instance.library_file(@spec)}.zip"
        res = File.exist?(zip_file)
        unless res
          zip_file = CBin::Config::Builder.instance.framework_zip_file(@spec) + ".zip"
          res = File.exist?(zip_file)
        end
        if res
          upload_zip(zip_file)
        end

        res
      end

      def upload_zip(zip_file)
        raise Pod::Informative, "Missing binary archive: #{zip_file}" unless File.file?(zip_file)
        output, status = Open3.capture2e('curl', '--fail', '--silent', '--show-error',
                                       '--connect-timeout', '10', '--max-time', '300',
                                       CBin.config.binary_upload_url,
                                       '--form-string', "name=#{@spec.name}",
                                       '--form-string', "version=#{@spec.version}",
                                       '--form-string', "annotate=#{@spec.name}_#{@spec.version}_log",
                                       '-F', "file=@#{zip_file}")
        raise Pod::Informative, "Binary upload failed: #{output}" unless status.success?
        Pod::UI.puts(output)
        true
      end


      # 上传二进制 podspec
      def push_binary_repo(binary_podsepc_json)
        argvs = [
            "#{binary_podsepc_json}",
            "--binary",
            "--sources=#{sources_option(@code_dependencies, @sources)},https:\/\/cdn.cocoapods.org",
            "--skip-import-validation",
            "--use-libraries",
            "--allow-warnings",
            "--verbose",
            "--code-dependencies"
        ]
        if @verbose
          argvs += ['--verbose']
        end

        push = Pod::Command::Bin::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.validate!
        push.run
      end

    end
  end
end

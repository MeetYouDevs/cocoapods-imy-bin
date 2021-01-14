

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-imy-bin/helpers/framework_builder'
require 'cocoapods-imy-bin/helpers/library_builder'
require 'cocoapods-imy-bin/helpers/sources_helper'
require 'cocoapods-imy-bin/command/bin/spec/push'

module CBin
  class Upload
    class Helper
      include CBin::SourcesHelper

      def initialize(spec,code_dependencies,sources)
        @spec = spec
        @code_dependencies = code_dependencies
        @sources = sources
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
        spec_creator = CBin::SpecificationSource::Creator.new(@spec)
        spec_creator.create
        spec_creator.write_spec_file
        spec_creator.filename
      end

      #推送二进制
      # curl http://ci.xxx:9192/frameworks -F "name=IMYFoundation" -F "version=7.7.4.2" -F "annotate=IMYFoundation_7.7.4.2_log" -F "file=@bin-zip/bin_IMYFoundation_7.7.4.2.zip"
      def curl_zip
        zip_file = "#{CBin::Config::Builder.instance.library_file(@spec)}.zip"
        res = File.exist?(zip_file)
        unless res
          zip_file = CBin::Config::Builder.instance.framework_zip_file(@spec) + ".zip"
          res = File.exist?(zip_file)
        end
        if res
          command = "curl #{CBin.config.binary_upload_url} -F \"name=#{@spec.name}\" -F \"version=#{@spec.version}\" -F \"annotate=#{@spec.name}_#{@spec.version}_log\" -F \"file=@#{zip_file}\""
          print <<EOF
          上传二进制文件
          #{command}
EOF
          upload_result = `#{command}`
          puts "#{upload_result}"
        end

        res
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

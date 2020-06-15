
require 'cocoapods-imy-bin/command/bin/update'
module Pod
  class Command
    class Bin < Command
      class Install < Bin
        include Pod

        self.summary = 'pod install 拦截器，会加载本地Podfile_local文件，DSL加载到原始Podfile文件中。'

        self.description = <<-DESC
          pod install 拦截器，会加载本地Podfile_local文件
          会通过DSL加载到原始Podfile文件中
          支持 pod 'xxx' 各种写法
          支持 post_install/pre_install钩子，采用覆盖做法
        DESC
        def self.options
          [
            ['--repo-update', 'Force running `pod repo update` before install'],
            ['--deployment', 'Disallow any changes to the Podfile or the Podfile.lock during installation'],
            ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
          'applies to projects that have enabled incremental installation']
          ].concat(super).reject { |(name, _)| name == '--no-repo-update' }
        end

        def initialize(argv)
          @update = argv.flag?('update')
          super
          @additional_args = argv.remainder!
        end

        def run
          Update.load_local_podfile
          argvs = [
            *@additional_args
          ]
          gen = Pod::Command::Install.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end
      end
    end
  end
end

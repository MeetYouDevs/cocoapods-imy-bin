require 'cocoapods-imy-bin/config/config'
require 'cocoapods-imy-bin/native/podfile'

module Pod
  class Command
    class Bin < Command
      class Lib < Bin
        class Lint < Lib
          self.summary = 'lint 组件.'
          self.description = <<-DESC
            lint 二进制组件 / 源码组件
          DESC

          self.arguments = [
            CLAide::Argument.new('NAME.podspec', false)
          ]

          # lib lint 不会下载 source，所以不能进行二进制 lint
          # 要 lint 二进制版本，需要进行 spec lint，此 lint 会去下载 source
          def self.options
            [
              ['--code-dependencies', '使用源码依赖进行 lint'],
              ['--loose-options', '添加宽松的 options, 包括 --use-libraries (可能会造成 entry point (start) undefined)'],
              ['--allow-prerelease', '允许使用 prerelease 的版本 lint']
            ].concat(Pod::Command::Lib::Lint.options).concat(super).uniq
          end

          def initialize(argv)
            @loose_options = argv.flag?('loose-options')
            @code_dependencies = argv.flag?('code-dependencies')
            @sources = argv.option('sources') || []
            @allow_prerelease = argv.flag?('allow-prerelease')
            @podspec = argv.shift_argument
            super

            @additional_args = argv.remainder!
          end

          def run
            Podfile.execute_with_bin_plugin do
              Podfile.execute_with_allow_prerelease(@allow_prerelease) do
                Podfile.execute_with_use_binaries(!@code_dependencies) do
                  argvs = [
                    @podspec || code_spec_files.first,
                    "--sources=#{sources_option(@code_dependencies, @sources)}",
                    *@additional_args
                  ]

                  if @loose_options
                    argvs << '--allow-warnings'
                    if code_spec&.all_dependencies&.any?
                      argvs << '--use-libraries'
                    end
                  end

                  lint = Pod::Command::Lib::Lint.new(CLAide::ARGV.new(argvs))
                  lint.validate!
                  lint.run
                end
              end
            end
          end


        end
      end
    end
  end
end

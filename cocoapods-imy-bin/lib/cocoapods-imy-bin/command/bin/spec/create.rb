require 'cocoapods-imy-bin/helpers'

module Pod
  class Command
    class Bin < Command
      class Spec < Bin
        class Create < Spec
          self.summary = '创建二进制 spec.'
          self.description = <<-DESC
            根据源码 podspec 文件，创建对应的二进制 podspec 文件.
          DESC

          def self.options
            [
              ['--platforms=ios', '生成二进制 spec 支持的平台'],
              ['--template-podspec=A.binary-template.podspec', '生成拥有 subspec 的二进制 spec 需要的模版 podspec, 插件会更改 version 和 source'],
              ['--no-overwrite', '不允许覆盖']
            ].concat(super)
          end

          def initialize(argv)
            @platforms = argv.option('platforms', 'ios')
            @allow_overwrite = argv.flag?('overwrite', true)
            @template_podspec = argv.option('template-podspec')
            @podspec = argv.shift_argument
            super
          end

          def run
            UI.puts "开始读取 podspec 文件...\n"

            code_spec = Pod::Specification.from_file(spec_file)
            if template_spec_file
              template_spec = Pod::Specification.from_file(template_spec_file)
            end

            if binary_spec && !@allow_overwrite
              UI.warn "二进制 podspec 文件 #{binary_spec_files.first} 已存在.\n"
            else
              UI.puts "开始生成二进制 podspec 文件...\n"
              spec_file = create_binary_spec_file(code_spec, template_spec)
              UI.puts "创建二进制 podspec 文件 #{spec_file} 成功.\n".green
            end
          end

          def template_spec_file
            @template_spec_file ||= begin
              if @template_podspec
                find_spec_file(@template_podspec)
              else
                binary_template_spec_file
              end
            end
          end

          def spec_file
            @spec_file ||= begin
              if @podspec
                find_spec_file(@podspec)
              else
                if code_spec_files.empty?
                  raise Informative, '当前目录下没有找到可用源码 podspec.'
                end

                code_spec_files.first
              end
            end
          end
        end
      end
    end
  end
end

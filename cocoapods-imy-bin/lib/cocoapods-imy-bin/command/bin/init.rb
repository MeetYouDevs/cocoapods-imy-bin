require 'cocoapods-imy-bin/config/config_asker'

module Pod
  class Command
    class Bin < Command
      class Init < Bin
        self.summary = '初始化插件的快捷键.'
        self.description = <<-DESC
          创建  文件，在其中保存插件需要的配置信息，
          如快捷键1 快捷键2 所对应执行的命令
        DESC

        def self.options
          [
            ['--bin-url=URL', '配置文件地址，直接从此地址下载配置文件']
          ].concat(super)
        end

        def initialize(argv)
          @bin_url = argv.option('bin-url')
          super
        end

        def run
          if @bin_url.nil?
            config_with_asker
          else
            config_with_url(@bin_url)
          end
        end

        private

        def config_with_url(url)
          require 'open-uri'

          UI.puts "开始下载配置文件...\n"
          file = open(url)
          contents = YAML.safe_load(file.read)

          UI.puts "开始同步配置文件...\n"
          CBin.config.sync_config(contents.to_hash)
          UI.puts "设置完成.\n".green
        rescue Errno::ENOENT => e
          raise Informative, "配置文件路径 #{url} 无效，请确认后重试."
        end

        def config_with_asker
          asker = CBin::Config::Asker.new
          asker.wellcome_message

          config = {}
          template_hash = CBin.config.template_hash
          template_hash.each do |k, v|
            default = begin
                        CBin.config.send(k)
                      rescue StandardError
                        nil
                      end
            config[k] = asker.ask_with_answer(v[:description], default, v[:selection])
          end

          CBin.config.sync_config(config)
          asker.done_message
        end
      end
    end
  end
end

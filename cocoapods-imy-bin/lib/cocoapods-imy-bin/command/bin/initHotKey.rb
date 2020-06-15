
require 'cocoapods-imy-bin/config/config_hot_key_asker'

module Pod
  class Command
    class Bin < Command
      class Inithk < Bin
        self.summary = '初始化快捷键配置.'
        self.description = <<-DESC
          创建  文件，在其中保存插件需要的配置信息，
          如二进制私有源地址、源码私有源地址等。
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
          CBin.config_hot_key.sync_config(contents.to_hash)
          UI.puts "设置完成.\n".green
        rescue Errno::ENOENT => e
          raise Informative, "配置文件路径 #{url} 无效，请确认后重试."
        end

        def config_with_asker
          asker = CBin::Config_Hot_Key::Asker.new
          asker.wellcome_message

          config = {}
          template_hash = CBin.config_hot_key.template_hash
          template_hash.each do |k, v|
            default = begin
                        CBin.config_hot_key.send(k)
                      rescue StandardError
                        nil
                      end
            config[k] = asker.ask_with_answer(v[:description], default, v[:selection])
          end

          CBin.config_hot_key.sync_config(config)
          asker.done_message
        end
      end
    end
  end
end

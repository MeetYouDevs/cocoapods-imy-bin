require 'yaml'
require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods-imy-bin/native/podfile_env'
require 'cocoapods/generate'

module CBin
  class Config_Hot_Key

    def config_file
      config_file_with_hot_key_index(hot_key_index)
    end

    def template_hash
      {
          'hot_key_index' => { description: '快捷键', default: '1', selection: %w[1 2 3...] },
          'hot_key_dir'   => { description: '快捷键执行目录', default: '' },
          'hot_key_cmd'   => { description: '快捷键执行命令', default: 'pod bin update --no-repo-update' }
      }
    end

    def config_file_with_hot_key_index(hot_key_index)
      file = config_file_whith_hot_key_index(hot_key_index)
      raise "\n=====  #{hot_key_index} 参数有误，请检查%w[1 2 3...]===" unless (hot_key_index.to_i).is_a?(Integer)
      File.expand_path("#{Pod::Config.instance.home_dir}/#{file}")
    end

    def hot_key_index
      @hot_key_index = 1 if @hot_key_index.is_a?(NilClass)
      @hot_key_index
    end

    def set_hot_key_index(hot_key_index)
      @hot_key_index = hot_key_index
    end

    def config_file_whith_hot_key_index(hot_key_index)
      "hot_key_#{hot_key_index}.yml"
    end

    def sync_config(config)
      File.open(config_file_with_hot_key_index(config['hot_key_index']), 'w+') do |f|
        f.write(config.to_yaml)
      end
    end

    def default_config
      @default_config ||= Hash[template_hash.map { |k, v| [k, v[:default]] }]
    end

    private

    def load_config
      file = config_file
      if (!file.nil?) && File.exist?(config_file)
        YAML.load_file(config_file)
      else
        default_config
      end
    end

    def config
      @config ||= begin
                    puts "====== cocoapods-imy-bin #{CBin::VERSION} 版本 ======== \n"
                    @config = OpenStruct.new load_config
                    validate!
                    @config
                  end
    end

    def validate!
      template_hash.each do |k, v|
        selection = v[:selection]
        next if !selection || selection.empty?

        config_value = @config.send(k)
        next unless config_value
        unless selection.include?(config_value)
          raise Pod::Informative, "#{k} 字段的值必须限定在可选值 [ #{selection.join(' / ')} ] 内".red
        end
      end
    end

    def respond_to_missing?(method, include_private = false)
      config.respond_to?(method) || super
    end

    def method_missing(method, *args, &block)
      if config.respond_to?(method)
        config.send(method, *args)
      elsif template_hash.keys.include?(method.to_s)
        raise Pod::Informative, "#{method} 字段必须在配置文件 #{config_file} 中设置, 请执行 init 命令配置或手动修改配置文件".red
      else
        super
      end
    end
  end

  def self.config_hot_key
    @config_hot_key ||= Config_Hot_Key.new
  end

end


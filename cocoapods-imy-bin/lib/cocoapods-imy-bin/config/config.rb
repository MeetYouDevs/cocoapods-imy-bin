require 'yaml'
require 'cocoapods-imy-bin/native/podfile'
require 'cocoapods-imy-bin/native/podfile_env'
require 'cocoapods/generate'

module CBin
  class Config
    def config_file
      config_file_with_configuration_env(configuration_env)
    end

    def template_hash
      {
          'configuration_env' => { description: '编译环境', default: 'dev', selection: %w[dev debug_iphoneos release_iphoneos] },
          'code_repo_url' => { description: '源码私有源 Git 地址', default: 'git@github.com:su350380433/example_spec_source.git' },
          'binary_repo_url' => { description: '二进制私有源 Git 地址', default: 'git@github.com:su350380433/example_spec_bin_dev.git' },
          'binary_download_url' => { description: '二进制下载地址，内部会依次传入组件名称与版本，替换字符串中的 %s ', default: 'http://localhost:8080/frameworks/%s/%s.zip' },
          # 'binary_type' => { description: '二进制打包类型', default: 'framework', selection: %w[framework library] },
          'download_file_type' => { description: '下载二进制文件类型', default: 'zip', selection: %w[zip tgz tar tbz txz dmg] }
      }
    end

    def config_file_with_configuration_env(configuration_env)
      file = config_dev_file
      if configuration_env == "release_iphoneos"
        file = config_release_iphoneos_file
        puts "\n======  #{configuration_env} 环境 ========"
      elsif configuration_env == "debug_iphoneos"
        file = config_debug_iphoneos_file
        puts "\n======  #{configuration_env} 环境 ========"
      elsif configuration_env == "dev"
        puts "\n======  #{configuration_env} 环境 ========"
      else
        raise "\n=====  #{configuration_env} 参数有误，请检查%w[dev debug_iphoneos release_iphoneos]===="
      end

      File.expand_path("#{Pod::Config.instance.home_dir}/#{file}")
    end

    def configuration_env
      #如果是dev 再去 podfile的配置文件中获取，确保是正确的， pod update时会用到
      if @configuration_env == "dev" || @configuration_env == nil
        if Pod::Config.instance.podfile
          configuration_env ||= Pod::Config.instance.podfile.configuration_env
        end
        configuration_env ||= "dev"
        @configuration_env = configuration_env
      end
      @configuration_env
    end

    #上传的url
    def binary_upload_url
      cut_string = "/%s/%s/zip"
      binary_download_url[0,binary_download_url.length - cut_string.length]
    end

    def set_configuration_env(env)
      @configuration_env = env
    end

    #包含arm64  armv7架构，xcodebuild 是Debug模式
    def config_debug_iphoneos_file
      "bin_debug_iphoneos.yml"
    end
    #包含arm64  armv7架构，xcodebuild 是Release模式
    def config_release_iphoneos_file
      "bin_release_iphoneos.yml"
    end
    #包含x86 arm64  armv7架构，xcodebuild 是Release模式
    def config_dev_file
      "bin_dev.yml"
    end

    def sync_config(config)
      File.open(config_file_with_configuration_env(config['configuration_env']), 'w+') do |f|
        f.write(config.to_yaml)
      end
    end

    def default_config
      @default_config ||= Hash[template_hash.map { |k, v| [k, v[:default]] }]
    end

    private

    def load_config
      if File.exist?(config_file)
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

  def self.config
    @config ||= Config.new
  end


end

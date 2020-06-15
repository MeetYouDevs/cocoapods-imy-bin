

require 'cocoapods'
require 'cocoapods-imy-bin/native/podfile_env'

module Pod
  class Podfile
    # TREAT_DEVELOPMENTS_AS_NORMAL = 'treat_developments_as_normal'.freeze

    module DSL
      def allow_prerelease!
        set_internal_hash_value(ALLOW_PRERELEASE, true)
      end

      def use_binaries!(flag = true)
        set_internal_hash_value(USE_BINARIES, flag)
      end

      def use_binaries_with_spec_selector!(&block)
        raise Informative, '必须提供选择需要二进制组件的 block !' unless block_given?

        set_internal_hash_value(USE_BINARIES_SELECTOR, block)
      end

      def set_use_source_pods(pods)
        hash_pods_use_source = get_internal_hash_value(USE_SOURCE_PODS) || []
        hash_pods_use_source += Array(pods)
        set_internal_hash_value(USE_SOURCE_PODS, hash_pods_use_source)
      end

      # 0 dev
      # 1 debug_iphoneos
      # 2 release_iphoneos
      # 需要在podfile_env 先定义  CONFIGURATION_ENV
      def set_configuration_env(env = "dev")
        set_internal_hash_value(CONFIGURATION_ENV, env)
      end
    end

    alias old_plugins plugins
    def plugins
      if ENV[USE_PLUGINS]
        env_plugins = ENV[USE_PLUGINS].split(',').each_with_object({}) do |name, result|
          result[name] = {}
        end
        env_plugins.merge!(old_plugins)
      else
        old_plugins
      end
    end

    def use_binaries_selector
      get_internal_hash_value(USE_BINARIES_SELECTOR, nil)
    end

    def allow_prerelease?
      get_internal_hash_value(ALLOW_PRERELEASE, false) || ENV[ALLOW_PRERELEASE] == 'true'
    end

    def use_binaries?
      get_internal_hash_value(USE_BINARIES, false) || ENV[USE_BINARIES] == 'true'
    end

    def use_source_pods
      get_internal_hash_value(USE_SOURCE_PODS, []) + String(ENV[USE_SOURCE_PODS]).split('|').uniq
    end

    def configuration_env
      get_internal_hash_value(CONFIGURATION_ENV, "dev") ||  ENV[CONFIGURATION_ENV] == "dev"
    end

    private

    def valid_bin_plugin
      unless plugins.keys.include?('cocoapods-imy-bin')
        raise Pod::Informative, 'You should add `plugin \'cocoapods-imy-bin\'` before using its DSL'
      end
    end

    # set_hash_value 有 key 限制
    def set_internal_hash_value(key, value)
      valid_bin_plugin

      internal_hash[key] = value
    end

    def get_internal_hash_value(key, default = nil)
      internal_hash.fetch(key, default)
    end
  end
end

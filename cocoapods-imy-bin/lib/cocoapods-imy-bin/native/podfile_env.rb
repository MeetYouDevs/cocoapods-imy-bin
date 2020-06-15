

module Pod
  class Podfile
    USE_BINARIES = 'use_binaries'
    USE_SOURCE_PODS = 'use_source_pods'
    USE_BINARIES_SELECTOR = 'use_binaries_selector'
    ALLOW_PRERELEASE = 'allow_prerelease'
    USE_PLUGINS = 'use_plugins'
    CONFIGURATION_ENV = 'configuration_env'

    module ENVExecutor
      def execute_with_bin_plugin(&block)
        execute_with_key(USE_PLUGINS, -> { 'cocoapods-imy-bin' }, &block)
      end

      def execute_with_allow_prerelease(allow_prerelease, &block)
        execute_with_key(ALLOW_PRERELEASE, -> { allow_prerelease ? 'true' : 'false' }, &block)
      end

      def execute_with_use_binaries(use_binaries, &block)
        execute_with_key(USE_BINARIES, -> { use_binaries ? 'true' : 'false' }, &block)
      end

      def execute_with_key(key, value_returner)
        origin_value = ENV[key]
        ENV[key] = value_returner.call

        yield if block_given?

        ENV[key] = origin_value
      end
    end

    extend ENVExecutor
  end
end

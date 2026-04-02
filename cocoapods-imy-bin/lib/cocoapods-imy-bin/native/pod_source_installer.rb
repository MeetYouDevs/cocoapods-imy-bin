

require 'cocoapods-imy-bin/native/installation_options'

module Pod
  class Installer
    if const_defined?(:PodSourceDownloader)
      class PodSourceDownloader
        attr_accessor :installation_options

        if method_defined?(:verify_source_is_secure) && !method_defined?(:cbin_verify_source_is_secure)
          alias cbin_verify_source_is_secure verify_source_is_secure

          def verify_source_is_secure(root_spec)
            return unless installation_options.nil? || installation_options.warn_for_unsecure_source?

            cbin_verify_source_is_secure(root_spec)
          end
        end
      end
    end

    class PodSourceInstaller
      attr_accessor :installation_options

      if method_defined?(:verify_source_is_secure) && !method_defined?(:cbin_verify_source_is_secure)
        alias cbin_verify_source_is_secure verify_source_is_secure

        def verify_source_is_secure(root_spec)
          return unless installation_options.nil? || installation_options.warn_for_unsecure_source?

          cbin_verify_source_is_secure(root_spec)
        end
      end
    end
  end
end

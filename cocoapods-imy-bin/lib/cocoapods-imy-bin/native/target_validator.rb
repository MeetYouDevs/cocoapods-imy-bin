module Pod
  class Installer
    class Xcode
      # The {Xcode::TargetValidator} ensures that the pod and aggregate target
      # configuration is valid for installation.
      #
      class TargetValidator



        def verify_swift_pods_have_module_dependencies
          error_messages = []
          pod_targets.each do |pod_target|
            next unless pod_target.uses_swift?

            non_module_dependencies = []
            pod_target.dependent_targets.each do |dependent_target|
              next if !dependent_target.should_build? || dependent_target.defines_module?
              non_module_dependencies << dependent_target.name
            end

            next if non_module_dependencies.empty?

            error_messages << "The Swift pod `#{pod_target.name}` depends upon #{non_module_dependencies.map { |d| "`#{d}`" }.to_sentence}, " \
                              "which #{non_module_dependencies.count == 1 ? 'does' : 'do'} not define modules. " \
                              'To opt into those targets generating module maps '\
                              '(which is necessary to import them from Swift when building as static libraries), ' \
                              'you may set `use_modular_headers!` globally in your Podfile, '\
                              'or specify `:modular_headers => true` for particular dependencies.'
          end
          return false

          # raise Informative, 'The following Swift pods cannot yet be integrated '\
                             # "as static libraries:\n\n#{error_messages.join("\n\n")}"
        end


      end
    end
  end
end

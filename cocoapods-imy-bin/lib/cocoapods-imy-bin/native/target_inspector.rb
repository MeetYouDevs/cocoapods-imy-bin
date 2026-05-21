require 'active_support/core_ext/array/conversions'
require 'pathname'
require 'cocoapods-imy-bin/native/podfile_env'

if defined?(Pod::Installer::Analyzer::TargetInspector)
  module Pod
    class Installer
      class Analyzer
        class IgnoreMissingTargetDefinition < StandardError
          attr_reader :target_definition

          def initialize(target_definition, message)
            @target_definition = target_definition
            super(message)
          end
        end

        class TargetInspector
          private

          def compute_targets(user_project)
            native_targets = user_project.native_targets
            target = native_targets.find { |t| t.name == target_definition.name.to_s }
            return [target] if target

            found = native_targets.map { |t| "`#{t.name}`" }.to_sentence
            message = "Unable to find a target named `#{target_definition.name}` in project `#{Pathname(user_project.path).basename}`, did find #{found}."

            unless ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] == 'true'
              raise Informative, message
            end

            raise IgnoreMissingTargetDefinition.new(target_definition, message)
          end
        end
      end
    end
  end
end
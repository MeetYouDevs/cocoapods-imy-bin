

require 'parallel'
require 'cocoapods'
require 'cocoapods-imy-bin/native/pod_source_installer'

module Pod
  module Generate
    # Generates podfiles for pod specifications given a configuration.
    #
    class PodfileGenerator
      def podfile_for_spec(spec)
        build_podfile_for_specs(Array(spec), configuration.gen_dir_for_pod(spec.name), spec.name)
      end

      def podfile_for_specs(specs)
        build_podfile_for_specs(specs, configuration.gen_dir_for_specs(specs), configuration.project_name_for_specs(specs))
      end

      private

      def build_podfile_for_specs(specs, dir, project_name)
        generator = self
        use_frameworks_value = if generator.respond_to?(:use_frameworks_value)
                                 generator.use_frameworks_value
                               else
                                 generator.configuration.use_frameworks?
                               end

        Pod::Podfile.new do
          project "#{project_name}.xcodeproj"
          workspace "#{project_name}.xcworkspace"

          plugin 'cocoapods-generate'

          install! 'cocoapods', generator.installation_options

          generator.podfile_plugins.each do |name, options|
            plugin(*[name, options].compact)
          end

          use_frameworks!(use_frameworks_value)

          if (supported_swift_versions = generator.supported_swift_versions)
            supports_swift_versions(supported_swift_versions)
          end

          generator.configuration.sources.each do |source_url|
            source(source_url)
          end

          self.defined_in_file = dir.join('CocoaPods.podfile.yaml')

          test_specs_by_spec = Hash[specs.map do |spec|
            [spec, spec.recursive_subspecs.select(&:test_specification?)]
          end]
          app_specs_by_spec = Hash[specs.map do |spec|
            app_specs = if spec.respond_to?(:app_specification?)
                          spec.recursive_subspecs.select(&:app_specification?)
                        else
                          []
                        end
            [spec, app_specs]
          end]

          spec_platform_names = specs.flat_map { |spec| spec.available_platforms.map(&:string_name) }.uniq.reject do |platform_name|
            !generator.configuration.platforms.nil? && !generator.configuration.platforms.include?(platform_name.downcase)
          end

          spec_platform_names.sort.each do |platform_name|
            target "App-#{platform_name}" do
              current_target_definition.swift_version = generator.swift_version if generator.swift_version
            end
          end

          inhibit_all_warnings! if generator.inhibit_all_warnings?
          use_modular_headers! if generator.use_modular_headers?

          specs.each do |spec|
            pod_options = generator.dependency_compilation_kwargs(spec.name)
            pod_options[:path] = spec.defined_in_file.relative_path_from(dir).to_s

            { testspecs: test_specs_by_spec[spec], appspecs: app_specs_by_spec[spec] }.each do |key, subspecs|
              pod_options[key] = subspecs.map { |subspec| subspec.name.sub(%r{^#{Regexp.escape spec.root.name}/}, '') }.sort unless subspecs.empty?
            end

            pod spec.name, **pod_options
          end

          if Pod::Config.instance.podfile
            specs.each do |spec|
              target_definitions['Pods'].instance_exec do
                target_definition = nil
                Pod::Config.instance.podfile.target_definition_list.each do |target|
                  if target.label == "Pods-#{spec.name}"
                    target_definition = target
                    break
                  end
                end

                if target_definition && target_definition.use_modular_headers_hash.values.any?
                  target_definition.use_modular_headers_hash.values.each do |pod_names|
                    pod_names.each { |pod_name| self.set_use_modular_headers_for_pod(pod_name, true) }
                  end
                end

                if target_definition
                  value = target_definition.to_hash['dependencies']
                  next if value.blank?

                  value.each do |dependency|
                    if dependency.is_a?(Hash) && dependency.keys.first == spec.name
                      value.delete(dependency)
                      break
                    end
                  end

                  old_value = self.to_hash['dependencies'].first
                  value << old_value unless old_value.nil? || value.include?(old_value)
                  set_hash_value(%w(dependencies).first, value)

                  value = target_definition.to_hash['configuration_pod_whitelist']
                  next if value.blank?

                  set_hash_value(%w(configuration_pod_whitelist).first, value)
                end
              end
            end
          end

          next if generator.configuration.local_sources.empty?

          specs.each do |spec|
            generator.transitive_local_dependencies(spec, generator.configuration.local_sources).each do |dependency, podspec_file|
              pod_options = generator.dependency_compilation_kwargs(dependency.name)
              pod_options[:path] = if podspec_file[0] == '/'
                                     podspec_file
                                   else
                                     '../../' + podspec_file
                                   end
              pod dependency.name, **pod_options
            end
          end
        end
      end
    end
  end
end


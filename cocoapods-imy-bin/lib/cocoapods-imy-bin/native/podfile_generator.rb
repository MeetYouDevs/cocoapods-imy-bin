

require 'parallel'
require 'cocoapods'
require 'cocoapods-imy-bin/native/pod_source_installer'


require 'parallel'
require 'cocoapods'

module Pod
  module Generate
    # Generates podfiles for pod specifications given a configuration.
    #
    class PodfileGenerator
      # @return [Podfile] a podfile suitable for installing the given spec
      #
      # @param  [Specification] spec
      #
      alias old_podfile_for_spec podfile_for_spec

      def podfile_for_spec(spec)
        generator = self
        dir = configuration.gen_dir_for_pod(spec.name)

        Pod::Podfile.new do
          project "#{spec.name}.xcodeproj"
          workspace "#{spec.name}.xcworkspace"

          plugin 'cocoapods-generate'

          install! 'cocoapods', generator.installation_options

          generator.podfile_plugins.each do |name, options|
            plugin(*[name, options].compact)
          end

          use_frameworks!(generator.configuration.use_frameworks?)

          if (supported_swift_versions = generator.supported_swift_versions)
            supports_swift_versions(supported_swift_versions)
          end

          # Explicitly set sources
          generator.configuration.sources.each do |source_url|
            source(source_url)
          end

          self.defined_in_file = dir.join('CocoaPods.podfile.yaml')

          test_specs = spec.recursive_subspecs.select(&:test_specification?)
          app_specs = if spec.respond_to?(:app_specification?)
                        spec.recursive_subspecs.select(&:app_specification?)
                      else
                        []
                      end

          # Stick all of the transitive dependencies in an abstract target.
          # This allows us to force CocoaPods to use the versions / sources / external sources
          # that we want.
          # By using an abstract target,

          # 会导致多个dependencies出现， 注释by slj
          # abstract_target 'Transitive Dependencies' do
          #   pods_for_transitive_dependencies = [spec.name]
          #                                          .concat(test_specs.map(&:name))
          #                                          .concat(test_specs.flat_map { |ts| ts.dependencies.flat_map(&:name) })
          #                                          .concat(app_specs.map(&:name))
          #                                          .concat(app_specs.flat_map { |as| as.dependencies.flat_map(&:name) })
          #
          #   dependencies = generator
          #                      .transitive_dependencies_by_pod
          #                      .values_at(*pods_for_transitive_dependencies)
          #                      .compact
          #                      .flatten(1)
          #                      .uniq
          #                      .sort_by(&:name)
          #                      .reject { |d| d.root_name == spec.root.name }
          #
          #   dependencies.each do |dependency|
          #     pod_args = generator.pod_args_for_dependency(self, dependency)
          #     pod(*pod_args)
          #   end
          # end

          # Add platform-specific concrete targets that inherit the
          # `pod` declaration for the local pod.
          spec_platform_names = spec.available_platforms.map(&:string_name).flatten.each.reject do |platform_name|
            !generator.configuration.platforms.nil? && !generator.configuration.platforms.include?(platform_name.downcase)
          end

          spec_platform_names.sort.each do |platform_name|
            target "App-#{platform_name}" do
              current_target_definition.swift_version = generator.swift_version if generator.swift_version
            end
          end

          # this block has to come _before_ inhibit_all_warnings! / use_modular_headers!,
          # and the local `pod` declaration
          # 会导致多个dependencies出现， 注释by slj


          inhibit_all_warnings! if generator.inhibit_all_warnings?
          use_modular_headers! if generator.use_modular_headers?

          # This is the pod declaration for the local pod,
          # it will be inherited by the concrete target definitions below

          pod_options = generator.dependency_compilation_kwargs(spec.name)
          pod_options[:path] = spec.defined_in_file.relative_path_from(dir).to_s
          # generator.configuration.podfile.dependencies[0].external_source


          { testspecs: test_specs, appspecs: app_specs }.each do |key, specs|
            pod_options[key] = specs.map { |s| s.name.sub(%r{^#{Regexp.escape spec.root.name}/}, '') }.sort unless specs.empty?
          end

          pod spec.name, **pod_options

          if Pod::Config.instance.podfile
            target_definitions['Pods'].instance_exec do
              target_definition = nil
              Pod::Config.instance.podfile.target_definition_list.each do |target|
                if target.label == "Pods-#{spec.name}"
                  target_definition = target
                  break
                end
              end
              if target_definition
                value = target_definition.to_hash['dependencies']
                next if value.blank?
                #删除 本地库中的 spec.name，因为本地的./spec.name地址是错的
                value.each do |f|
                  if f.is_a?(Hash) && f.keys.first == spec.name
                    value.delete f
                    break
                  end
                end
                old_value = self.to_hash['dependencies'].first
                value << old_value unless (old_value == nil || value.include?(old_value))

               set_hash_value(%w(dependencies).first, value)

                value = target_definition.to_hash['configuration_pod_whitelist']
                next if value.blank?
                set_hash_value(%w(configuration_pod_whitelist).first, value)

                # self.children = Array.new
              end

            end

          end

          # if generator.configuration && generator.configuration.podfile
          #   #变量本地podfile下的dependencies 写入新的验证文件中，指定依赖源
          #   generator.configuration.podfile.dependencies.each { |dependencies|
          #     #如果不存在dependencies.external_source，就不变量
          #     next unless dependencies.external_source
          #
          #     dependencies.external_source.each { |key_d, value|
          #       pod_options = generator.dependency_compilation_kwargs(dependencies.name)
          #       pod_options[key_d] = value.to_s
          #       { testspecs: test_specs, appspecs: app_specs }.each do |key, specs|
          #         pod_options[key] = specs.map { |s| s.name.sub(%r{^#{Regexp.escape spec.root.name}/}, '') }.sort unless specs.empty?
          #       end
          #       # 过滤 dependencies.name == spec.name
          #       pod(dependencies.name, **pod_options) unless dependencies.name == spec.name
          #     }
          #   }
          # end


          # Implement local-sources option to set up dependencies to podspecs in the local filesystem.
          next if generator.configuration.local_sources.empty?
          generator.transitive_local_dependencies(spec, generator.configuration.local_sources).each do |dependency, podspec_file|
            pod_options = generator.dependency_compilation_kwargs(dependency.name)
            pod_options[:path] = if podspec_file[0] == '/' # absolute path
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


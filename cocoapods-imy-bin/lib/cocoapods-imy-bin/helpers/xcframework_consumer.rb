require 'set'

module CBin
  module XCFrameworkConsumer
    EVOLUTION_SETTING = 'IMY_BINARY_LIBRARY_EVOLUTION'.freeze

    # Binary interfaces compiled against resilient Swift dependencies must not
    # link to a source build with a different ABI for those dependency types.
    def self.configure(context)
      targets = context.aggregate_targets.flat_map(&:pod_targets).uniq
      required = Set.new
      visited = Set.new
      visit = lambda do |target|
        next unless visited.add?(target)
        required << target.label if target.should_build? && target.uses_swift?
        target.dependent_targets.each { |dependency| visit.call(dependency) }
      end
      targets.each do |target|
        settings = target.root_spec.consumer(target.platform.name).pod_target_xcconfig
        next unless settings[EVOLUTION_SETTING] == 'YES'
        target.dependent_targets.each { |dependency| visit.call(dependency) }
      end
      return if required.empty?

      found = Set.new
      context.generated_projects.compact.each do |project|
        changed = false
        project.native_targets.each do |target|
          next unless required.include?(target.name)
          found << target.name
          target.build_configurations.each do |configuration|
            next if configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] == 'YES'
            configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
            changed = true
          end
        end
        project.save if changed
      end
      missing = required - found
      raise Pod::Informative, "Missing Swift dependency targets: #{missing.to_a.join(', ')}" unless missing.empty?
    end
  end
end

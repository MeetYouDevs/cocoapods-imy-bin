require 'json'
require 'set'

module CBin
  # Scope generated static frameworks and the resolved CocoaPods model to one
  # invocation. Ordinary pod installs must not inherit this build configuration.
  class XCFrameworkBuildContext
    KEY = :cbin_xcframework_build_context
    attr_accessor :targets

    def initialize
      @targets = []
    end

    def self.current
      Thread.current[KEY]
    end

    def self.capture
      previous = current
      context = new
      Thread.current[KEY] = context
      yield
      context
    ensure
      Thread.current[KEY] = previous
    end

    def ordered_targets(root_name, include_dependencies)
      roots = targets.select { |target| target.root_spec.name == root_name && target.platform.name == :ios }
      raise Pod::Informative, "Expected one iOS target for #{root_name}, found #{roots.length}." unless roots.length == 1
      ordered = []
      active = Set.new
      seen = {}
      visit = lambda do |target|
        name = target.root_spec.name
        raise Pod::Informative, "Cyclic dependency at #{name}" if active.include?(name)
        if seen[name]
          raise Pod::Informative, "Multiple target variants for #{name}" unless seen[name].equal?(target)
          next
        end
        active << name
        target.dependent_targets.each { |dependency| visit.call(dependency) }
        active.delete(name)
        seen[name] = target
        ordered << target
      end
      visit.call(roots.first)
      include_dependencies ? ordered : [roots.first]
    end

    def self.spec_with_resolved_dependencies(target)
      hash = JSON.parse(target.root_spec.to_json)
      versions = target.dependent_targets.to_h { |dependency| [dependency.root_spec.name, dependency.root_spec.version.to_s] }
      [hash, hash['ios']].compact.each do |attributes|
        (attributes['dependencies'] || {}).each_key do |name|
          version = versions[name.split('/').first]
          raise Pod::Informative, "Unresolved dependency #{name} for #{target.root_spec.name}" unless version
          attributes['dependencies'][name] = ["= #{version}"]
        end
      end
      spec = Pod::Specification.from_hash(hash)
      spec.defined_in_file = target.root_spec.defined_in_file
      spec
    end
  end
end

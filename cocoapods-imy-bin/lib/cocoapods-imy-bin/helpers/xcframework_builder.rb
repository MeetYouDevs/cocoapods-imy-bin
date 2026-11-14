require 'fileutils'
require 'open3'
require 'tmpdir'
require 'xcodeproj'

module CBin
  # Keep SDK slices separate and let CocoaPods compile raw resources for the
  # consuming platform. Static frameworks retain Swift modules without embedding
  # their dependencies' binaries or platform-specific resource bundles.
  class XCFrameworkBuilder
    def initialize(spec, workspace, output_dir, configuration, pod_target: nil)
      @spec = spec
      @workspace = File.expand_path(workspace)
      @output_dir = File.expand_path(output_dir)
      @configuration = configuration
      @pod_target = pod_target
    end

    def validate!
      consumer = @spec.consumer(:ios)
      unsupported = @spec.subspecs.any? ||
                    @spec.available_platforms.any? { |platform| platform.name != :ios } ||
                    consumer.vendored_libraries.any? || consumer.vendored_frameworks.any? || consumer.on_demand_resources.any? ||
                    @spec.prepare_command || @spec.script_phases.any? || consumer.script_phases.any? || @spec.module_map
      if unsupported
        raise Pod::Informative, '--xcframework does not yet support subspecs, non-iOS platforms, vendored inputs, on-demand resources, custom module maps or build scripts.'
      end
      unless @pod_target && @pod_target.should_build? && @pod_target.build_as_static_framework?
        raise Pod::Informative, "Expected a resolved static framework target for #{@spec.name}."
      end
      consumer.resources.each { |path| self.class.resource_path(path) }
      consumer.resource_bundles.each_value { |paths| paths.each { |path| self.class.resource_path(path) } }
      true
    end

    def self.resource_path(path)
      pathname = Pathname.new(path)
      if pathname.absolute? || pathname.each_filename.include?('..')
        raise Pod::Informative, "Resource path must stay inside the pod: #{path}"
      end
      File.join('Resources', path)
    end

    def build
      validate!
      project_path = File.join(@workspace, 'Pods/Pods.xcodeproj')
      project_path = File.join(@workspace, 'Pods.xcodeproj') unless File.exist?(project_path)
      project = Xcodeproj::Project.open(project_path)
      target = project.native_targets.find { |item| item.name == @pod_target.label }
      raise Pod::Informative, "Missing native target #{@pod_target.label}" unless target
      scheme = Xcodeproj::XCScheme.new
      scheme.add_build_target(target)
      scheme.save_as(project_path, target.name, true)

      FileUtils.mkdir_p(@output_dir)
      Dir.mktmpdir('xcframework-', @output_dir) do |staging|
        frameworks = []
        [['iphoneos', 'iOS'], ['iphonesimulator', 'iOS Simulator']].each do |sdk, platform|
          derived = File.join(staging, sdk)
          run_command('xcodebuild', '-project', project_path, '-scheme', target.name,
                      '-configuration', @configuration, '-sdk', sdk,
                      '-destination', "generic/platform=#{platform}", '-derivedDataPath', derived,
                      "SYMROOT=#{File.join(derived, 'Build/Products')}",
                      "OBJROOT=#{File.join(derived, 'Build/Intermediates.noindex')}",
                      'ONLY_ACTIVE_ARCH=NO', 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES',
                      'CODE_SIGNING_ALLOWED=NO', 'build')
          products = File.join(derived, 'Build/Products', "#{@configuration}-#{sdk}")
          candidates = Dir.glob(File.join(products, '**', @pod_target.framework_name)).map { |path| File.realpath(path) }.uniq
          raise Pod::Informative, "Expected one #{@pod_target.framework_name} in #{products}, found #{candidates.length}." unless candidates.length == 1
          framework = File.join(staging, "#{sdk}-package", @pod_target.framework_name)
          copy_framework(candidates.first, framework)
          frameworks.concat(['-framework', framework])
        end

        package = File.join(staging, 'package')
        FileUtils.mkdir_p(package)
        framework = "#{@pod_target.product_module_name}.xcframework"
        run_command('xcodebuild', '-create-xcframework', *frameworks, '-output', File.join(package, framework))
        copy_resources(package)
        copy_license(package)
        zip = File.join(staging, "#{@spec.name}.xcframework_#{@spec.version}.zip")
        Dir.chdir(package) { run_command('zip', '-r', zip, '.') }
        destination = File.join(@output_dir, File.basename(zip))
        FileUtils.mv(zip, destination)
        destination
      end
    end

    private

    def copy_framework(source, destination)
      # Compiled resources inside a static framework are not portable across
      # SDKs. Only code/module metadata belongs here; raw resources ship beside it.
      [@pod_target.product_module_name, 'Headers', 'Modules', 'Info.plist'].each do |name|
        path = File.join(source, name)
        copy_tree(path, File.join(destination, name), source) if File.exist?(path)
      end
      binary = File.join(destination, @pod_target.product_module_name)
      raise Pod::Informative, "Missing framework executable: #{binary}" unless File.file?(binary)
      if @pod_target.uses_swift? && Dir.glob(File.join(destination, 'Modules/**/*.swiftinterface')).empty?
        raise Pod::Informative, "Missing Swift module interfaces for #{@spec.name}"
      end
    end

    def copy_resources(package)
      @pod_target.file_accessors.select { |accessor| accessor.spec.library_specification? }.each do |accessor|
        (accessor.resources + accessor.resource_bundles.values.flatten).uniq.each do |resource|
          relative = resource.relative_path_from(accessor.root).to_s
          destination = File.join(package, self.class.resource_path(relative))
          copy_tree(resource.to_s, destination, accessor.root.to_s)
        end
      end
    end

    def copy_license(package)
      license = @spec.license[:file]
      return unless license
      pathname = Pathname.new(license)
      if pathname.absolute? || pathname.each_filename.include?('..')
        raise Pod::Informative, '--xcframework requires a license path inside the pod directory.'
      end
      root = @pod_target.file_accessors.first.root.to_s
      copy_tree(File.join(root, license), File.join(package, license), root)
    end

    def copy_tree(source, destination, root, ancestors = [])
      real = File.realpath(source)
      allowed = File.realpath(root)
      unless real == allowed || real.start_with?(allowed + File::SEPARATOR)
        raise Pod::Informative, "Archive input escapes pod root: #{source}"
      end
      raise Pod::Informative, "Cyclic resource link: #{source}" if ancestors.include?(real)
      if File.directory?(source)
        FileUtils.mkdir_p(destination)
        Dir.children(source).sort.each do |name|
          copy_tree(File.join(source, name), File.join(destination, name), root, ancestors + [real])
        end
      else
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.copy_file(real, destination)
      end
    rescue Errno::ENOENT
      raise Pod::Informative, "Missing archive input: #{source}"
    end

    def run_command(*command)
      output, status = Open3.capture2e(*command)
      Pod::UI.puts(output)
      raise Pod::Informative, "Command failed: #{command.first}\n#{output}" unless status.success?
      output
    end
  end
end

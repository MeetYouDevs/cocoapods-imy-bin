require File.expand_path('../spec_helper', __dir__)
require 'tmpdir'
require 'cocoapods-imy-bin/helpers/xcframework_build_context'

describe 'XCFramework Swift, resources and dependencies' do
  def code_spec(name, version = '1.2.3')
    Pod::Specification.new do |spec|
      spec.name = name
      spec.version = version
      spec.platform = :ios, '15.0'
      spec.source = { git: 'file:///fixture', tag: version }
      spec.source_files = 'Sources/**/*.swift'
      spec.swift_versions = ['5.0']
    end
  end

  def resolved(spec, dependencies = [])
    stub(root_spec: spec, dependent_targets: dependencies, platform: Pod::Platform.new(:ios, '15.0'))
  end

  it 'restores generation state after a nested exception' do
    CBin::XCFrameworkBuildContext.current.should.be.nil?
    CBin::XCFrameworkBuildContext.capture do
      outer = CBin::XCFrameworkBuildContext.current
      lambda do
        CBin::XCFrameworkBuildContext.capture { raise 'fixture failure' }
      end.should.raise(RuntimeError)
      CBin::XCFrameworkBuildContext.current.should.equal outer
    end
    CBin::XCFrameworkBuildContext.current.should.be.nil?
  end

  it 'orders only the root dependency closure, once per shared dependency' do
    leaf = resolved(code_spec('Leaf'))
    first = resolved(code_spec('First'), [leaf])
    second = resolved(code_spec('Second'), [leaf])
    root = resolved(code_spec('Root'), [first, second])
    context = CBin::XCFrameworkBuildContext.new
    context.targets = [root, first, second, leaf, resolved(code_spec('UnrelatedTests'))]
    context.ordered_targets('Root', true).map { |target| target.root_spec.name }.should == %w[Leaf First Second Root]
    context.ordered_targets('Root', false).should == [root]
  end

  it 'rejects ambiguous dependency variants instead of choosing the first' do
    one = resolved(code_spec('Leaf'))
    two = resolved(code_spec('Leaf'))
    root = resolved(code_spec('Root'), [one, two])
    context = CBin::XCFrameworkBuildContext.new
    context.targets = [root, one, two]
    lambda { context.ordered_targets('Root', true) }.should.raise(Pod::Informative)
  end

  it 'pins root and platform dependencies without modifying the source specification' do
    spec = code_spec('Root')
    spec.dependency 'First', '~> 1.0'
    spec.ios.dependency 'Second', '>= 2.0'
    target = resolved(spec, [resolved(code_spec('First', '1.4.0')), resolved(code_spec('Second', '2.3.0'))])
    binary_input = CBin::XCFrameworkBuildContext.spec_with_resolved_dependencies(target)
    binary_input.to_hash['dependencies']['First'].should == ['= 1.4.0']
    binary_input.to_hash['ios']['dependencies']['Second'].should == ['= 2.3.0']
    spec.to_hash['dependencies']['First'].should == ['~> 1.0']
    spec.to_hash['ios']['dependencies']['Second'].should == ['>= 2.0']
  end

  it 'preserves Swift module identity, dependencies and resource bundle names' do
    spec = code_spec('Root')
    spec.module_name = 'PublicModule'
    spec.dependency 'Leaf', '= 1.2.3'
    spec.resources = 'Direct/*.txt'
    spec.ios.resource_bundles = { 'RootAssets' => ['Assets/*.lproj/*', 'Assets/Images.xcassets'] }
    CBin.config.stubs(:binary_download_url).returns('http://127.0.0.1/frameworks/%s/%s/zip')
    CBin.config.stubs(:download_file_type).returns('zip')
    binary = CBin::SpecificationSource::Creator.new(spec, 'ios', xcframework: true).create
    binary.module_name.should == 'PublicModule'
    binary.swift_versions.map(&:to_s).should == ['5.0']
    binary.static_framework.should == true
    binary.consumer(:ios).dependencies.first.requirement.to_s.should == '= 1.2.3'
    binary.consumer(:ios).resources.should == ['Resources/Direct/*.txt']
    binary.consumer(:ios).resource_bundles.should == { 'RootAssets' => ['Resources/Assets/*.lproj/*', 'Resources/Assets/Images.xcassets'] }
    spec.consumer(:ios).resources.should == ['Direct/*.txt']
  end

  it 'copies resolved resources with localization paths and exclusions intact' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'Assets/en.lproj'))
      File.write(File.join(dir, 'Assets/en.lproj/Localizable.strings'), '"key" = "value";')
      File.write(File.join(dir, 'Assets/excluded.json'), '{}')
      spec = code_spec('Root')
      spec.resource_bundles = { 'RootAssets' => ['Assets/**/*'] }
      spec.exclude_files = 'Assets/excluded.json'
      accessor = Pod::Sandbox::FileAccessor.new(Pathname.new(dir), spec.consumer(:ios))
      target = stub(file_accessors: [accessor])
      builder = CBin::XCFrameworkBuilder.new(spec, dir, dir, 'Debug', pod_target: target)
      package = File.join(dir, 'package')
      builder.send(:copy_resources, package)
      File.read(File.join(package, 'Resources/Assets/en.lproj/Localizable.strings')).should == '"key" = "value";'
      File.exist?(File.join(package, 'Resources/Assets/excluded.json')).should == false
    end
  end

  it 'aligns only marked binary dependencies with the library-evolution ABI' do
    Dir.mktmpdir do |dir|
      project = Xcodeproj::Project.new(File.join(dir, 'Pods.xcodeproj'))
      selected = project.new_target(:framework, 'SwiftLeaf', :ios, '15.0')
      unrelated = project.new_target(:framework, 'Unrelated', :ios, '15.0')
      [selected, unrelated].each do |target|
        target.build_configurations.each { |configuration| configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO' }
      end
      project.save
      leaf = stub(label: 'SwiftLeaf', should_build?: true, uses_swift?: true, dependent_targets: [])
      bridge = stub(label: 'ObjCBridge', should_build?: true, uses_swift?: false, dependent_targets: [leaf])
      source = code_spec('Root')
      binary = CBin::SpecificationSource::Creator.new(source, 'ios', xcframework: true).create
      root = stub(root_spec: binary, platform: Pod::Platform.new(:ios, '15.0'), dependent_targets: [bridge])
      context = stub(aggregate_targets: [stub(pod_targets: [root])], generated_projects: [project])
      CBin::XCFrameworkConsumer.configure(context)
      saved = Xcodeproj::Project.open(project.path)
      saved.native_targets.find { |target| target.name == 'SwiftLeaf' }.build_configurations.each do |configuration|
        configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'].should == 'YES'
      end
      saved.native_targets.find { |target| target.name == 'Unrelated' }.build_configurations.each do |configuration|
        configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'].should == 'NO'
      end
      source.consumer(:ios).pod_target_xcconfig.should.be.empty
    end
  end

  it 'does not change unmarked third-party binaries or ordinary source installs' do
    spec = code_spec('ThirdParty')
    spec.vendored_frameworks = 'ThirdParty.xcframework'
    target = stub(root_spec: spec, platform: Pod::Platform.new(:ios, '15.0'))
    target.expects(:dependent_targets).never
    context = stub(aggregate_targets: [stub(pod_targets: [target])])
    context.expects(:generated_projects).never
    CBin::XCFrameworkConsumer.configure(context)
  end

  it 'rejects root and iOS on-demand resources before packaging' do
    [:root, :ios].each do |scope|
      spec = code_spec('Root')
      receiver = scope == :ios ? spec.ios : spec
      receiver.on_demand_resources = { 'Video' => ['Assets/video.mp4'] }
      target = stub(should_build?: true, build_as_static_framework?: true)
      builder = CBin::XCFrameworkBuilder.new(spec, '/tmp', '/tmp', 'Release', pod_target: target)
      builder.expects(:run_command).never
      lambda { builder.validate! }.should.raise(Pod::Informative)
    end
  end

  it 'rejects absolute and escaping resource patterns' do
    ['/outside/file.json', '../outside/*', 'Assets/../../outside'].each do |path|
      lambda { CBin::XCFrameworkBuilder.resource_path(path) }.should.raise(Pod::Informative)
    end
  end

  it 'rejects missing inputs and symlinks outside the source root' do
    Dir.mktmpdir do |dir|
      root = File.join(dir, 'pod')
      FileUtils.mkdir_p(root)
      external = File.join(dir, 'external.txt')
      File.write(external, 'fixture')
      File.symlink(external, File.join(root, 'link.txt'))
      builder = CBin::XCFrameworkBuilder.new(code_spec('Root'), root, root, 'Debug')
      lambda { builder.send(:copy_tree, File.join(root, 'link.txt'), File.join(dir, 'output'), root) }.should.raise(Pod::Informative)
      lambda { builder.send(:copy_tree, File.join(root, 'missing'), File.join(dir, 'output'), root) }.should.raise(Pod::Informative)
    end
  end
end

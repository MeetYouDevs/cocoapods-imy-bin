require File.expand_path('../spec_helper', __dir__)
require 'tmpdir'

describe 'XCFramework packaging' do
  before do
    @spec = Pod::Specification.new do |s|
      s.name = 'TinyMath'
      s.version = '0.1.0'
      s.platform = :ios, '15.0'
      s.source = { git: 'file:///tmp/TinyMath', tag: '0.1.0' }
      s.source_files = 'Sources/*.{h,m}'
      s.public_header_files = 'Sources/*.h'
      s.license = { type: 'MIT', file: 'LICENSE' }
    end
  end

  it 'replaces source compilation with a vendored XCFramework' do
    CBin.config.stubs(:binary_download_url).returns('http://127.0.0.1:18080/frameworks/%s/%s/zip')
    CBin.config.stubs(:download_file_type).returns('zip')
    creator = CBin::SpecificationSource::Creator.new(@spec, 'ios', xcframework: true)
    binary = creator.create
    binary.source[:http].should == 'http://127.0.0.1:18080/frameworks/TinyMath/0.1.0/zip'
    binary.consumer(:ios).vendored_frameworks.should == ['TinyMath.xcframework']
    binary.consumer(:ios).source_files.should.be.empty
    binary.consumer(:ios).public_header_files.should.be.empty
    @spec.consumer(:ios).source_files.should == ['Sources/*.{h,m}']
  end

  it 'uses the module name for CocoaPods XCFramework linker flags' do
    @spec.module_name = 'CustomMath'
    binary = CBin::SpecificationSource::Creator.new(@spec, 'ios', xcframework: true).create
    binary.consumer(:ios).vendored_frameworks.should == ['CustomMath.xcframework']
    binary.module_name.should == 'CustomMath'
  end

  it 'clears platform-specific source compilation settings' do
    @spec.ios.source_files = 'iOS/*.m'
    @spec.ios.public_header_files = 'iOS/*.h'
    CBin.config.stubs(:binary_download_url).returns('http://127.0.0.1:18080/frameworks/%s/%s/zip')
    CBin.config.stubs(:download_file_type).returns('zip')
    binary = CBin::SpecificationSource::Creator.new(@spec, 'ios', xcframework: true).create
    binary.consumer(:ios).source_files.should.be.empty
    binary.consumer(:ios).public_header_files.should.be.empty
    @spec.consumer(:ios).source_files.should.include 'iOS/*.m'
  end

  it 'resolves source dependencies when rebuilding an XCFramework' do
    command = Pod::Command::Bin::Archive.new(CLAide::ARGV.new(%w[--xcframework]))
    command.expects(:sources_option).with(true, []).returns('file:///source-specs')
    command.stubs(:spec_file).returns('/tmp/TinyMath.podspec')
    CBin::Config::Builder.stubs(:instance).returns(stub(gen_dir: '/tmp/xcframework-test'))
    generated = mock('generator')
    generated.expects(:validate!)
    generated.expects(:run)
    Pod::Command::Gen.expects(:new).returns(generated)
    command.send(:generate_project)
  end

  it 'rejects conflicting archive modes without generating a project' do
    command = Pod::Command::Bin::Archive.new(CLAide::ARGV.new(%w[--xcframework --framework-output]))
    command.expects(:generate_project).never
    lambda { command.run }.should.raise(Pod::Informative)
  end

  it 'rejects conflicting auto modes before building or uploading' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'TinyMath.podspec.json')
      File.write(path, @spec.to_json)
      %w[--no-zip --framework-output].each do |option|
        command = Pod::Command::Bin::Auto.new(CLAide::ARGV.new([path, '--xcframework', option]))
        command.expects(:run_archive).never
        lambda { command.validate! }.should.raise(Pod::Informative)
      end
    end
  end

  it 'materializes archive input symlinks into standalone files' do
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'original.h')
      File.write(source, 'int add(int a, int b);')
      headers = File.join(dir, 'Pods/Headers/Public/TinyMath')
      FileUtils.mkdir_p(headers)
      File.symlink(source, File.join(headers, 'TinyMath.h'))
      destination = File.join(dir, 'packaged-headers')
      builder = CBin::XCFrameworkBuilder.new(@spec, dir, dir, 'Debug')
      builder.send(:copy_tree, headers, File.join(destination, 'TinyMath'), dir)
      File.unlink(source)
      File.symlink?(File.join(destination, 'TinyMath', 'TinyMath.h')).should == false
      File.read(File.join(destination, 'TinyMath', 'TinyMath.h')).should == 'int add(int a, int b);'
    end
  end

  it 'rejects unsupported build scripts before invoking a compiler' do
    @spec.script_phases = { name: 'unsupported', script: 'echo unsupported' }
    Dir.mktmpdir do |dir|
      builder = CBin::XCFrameworkBuilder.new(@spec, dir, dir, 'Debug')
      builder.expects(:run_command).never
      lambda { builder.build }.should.raise(Pod::Informative)
    end
  end

  it 'stops on a failed compiler or packaging command' do
    Dir.mktmpdir do |dir|
      builder = CBin::XCFrameworkBuilder.new(@spec, dir, dir, 'Debug')
      Open3.expects(:capture2e).with('false').returns(['compiler failed', stub(success?: false)])
      lambda { builder.send(:run_command, 'false') }.should.raise(Pod::Informative)
    end
  end

  it 'never publishes a spec after an HTTP upload failure' do
    Dir.mktmpdir do |dir|
      zip = File.join(dir, 'TinyMath.xcframework_0.1.0.zip')
      File.write(zip, 'fixture')
      CBin::Config::Builder.stubs(:instance).returns(CBin::Config::Builder.allocate)
      CBin::Config::Builder.instance.stubs(:root_dir).returns(dir)
      CBin::Config::Builder.instance.stubs(:xcframework_zip_file).with(@spec).returns(zip)
      CBin.config.stubs(:binary_upload_url).returns('http://127.0.0.1:18080/frameworks')
      helper = CBin::Upload::Helper.new(@spec, false, [], xcframework: true)
      Open3.expects(:capture2e).with { |*args| args.include?('--fail') }.returns(['HTTP 500', stub(success?: false)])
      helper.expects(:spec_creator).never
      helper.expects(:push_binary_repo).never
      lambda { helper.upload }.should.raise(Pod::Informative)
    end
  end
end

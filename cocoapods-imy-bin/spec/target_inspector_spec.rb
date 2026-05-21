require File.expand_path('./spec_helper', __dir__)

module Pod
  describe Installer::Analyzer::TargetInspector do
    before do
      UI.warnings = ''
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    after do
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    it 'raises by default when the user target does not exist' do
      target_definition = stub(name: 'Seeyou Today')
      user_project = stub(path: 'Seeyou.xcodeproj', native_targets: [stub(name: 'Seeyou')])
      inspector = Installer::Analyzer::TargetInspector.new(target_definition, Pathname('.'))

      lambda do
        inspector.send(:compute_targets, user_project)
      end.should.raise(Informative)
    end

    it 'raises a skip-target signal when ignore_missing_targets is enabled' do
      ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] = 'true'
      target_definition = stub(name: 'Seeyou Today')
      user_project = stub(path: 'Seeyou.xcodeproj', native_targets: [stub(name: 'Seeyou')])
      inspector = Installer::Analyzer::TargetInspector.new(target_definition, Pathname('.'))

      lambda do
        inspector.send(:compute_targets, user_project)
      end.should.raise(Installer::Analyzer::IgnoreMissingTargetDefinition)
    end
  end
end
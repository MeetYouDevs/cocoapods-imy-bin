require File.expand_path('./spec_helper', __dir__)

module Pod
  describe Installer::Analyzer do
    it 'filters target definitions skipped by --imt from resolved dependencies' do
      analyzer = Installer::Analyzer.allocate
      skipped_target = stub(name: 'Seeyou Today')
      kept_target = stub(name: 'Seeyou')
      resolver_specs_by_target = {
        skipped_target => ['SkippedPod'],
        kept_target => ['KeptPod'],
      }

      analyzer.instance_variable_set(:@ignored_missing_target_definitions, [skipped_target])

      analyzer.send(:reject_ignored_missing_target_definitions, resolver_specs_by_target).should == {
        kept_target => ['KeptPod'],
      }
    end
  end
end
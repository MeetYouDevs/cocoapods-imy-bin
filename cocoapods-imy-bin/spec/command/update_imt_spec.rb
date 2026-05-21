require File.expand_path('../spec_helper', __dir__)

module Pod
  describe Command::Bin::Update do
    before do
      UI.output = ''
      UI.warnings = ''
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    after do
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    it 'enables ignore_missing_targets only while the wrapped update runs' do
      command = Command::Bin::Update.new(CLAide::ARGV.new(%w(--imt)))
      update_runner = mock('update-runner')

      Pod::Command::Update.expects(:new).returns(update_runner)
      update_runner.expects(:validate!).with { ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] == 'true' }
      update_runner.expects(:run).with { ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] == 'true' }
      Command::Bin::Update.expects(:load_local_podfile)
      command.expects(:update_podfile_local_repo_if_needed)

      command.run

      ENV[Pod::Podfile::IGNORE_MISSING_TARGETS].should.be.nil?
    end
  end
end
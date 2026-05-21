require File.expand_path('../spec_helper', __dir__)

module Pod
  describe Command::Bin::Install do
    before do
      UI.output = ''
      UI.warnings = ''
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    after do
      ENV.delete(Pod::Podfile::IGNORE_MISSING_TARGETS)
    end

    it 'enables ignore_missing_targets only while the wrapped install runs' do
      command = Command::Bin::Install.new(CLAide::ARGV.new(%w(--imt)))
      install_runner = mock('install-runner')

      Pod::Command::Install.expects(:new).returns(install_runner)
      install_runner.expects(:validate!).with { ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] == 'true' }
      install_runner.expects(:run).with { ENV[Pod::Podfile::IGNORE_MISSING_TARGETS] == 'true' }
      Command::Bin::Update.expects(:load_local_podfile)

      command.run

      ENV[Pod::Podfile::IGNORE_MISSING_TARGETS].should.be.nil?
    end
  end
end
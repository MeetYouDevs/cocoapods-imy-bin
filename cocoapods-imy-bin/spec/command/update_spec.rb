require File.expand_path('../spec_helper', __dir__)
require 'tmpdir'

module Pod
  describe Command::Bin::Update do
    before do
      UI.output = ''
      UI.warnings = ''
    end

    it 'updates the Podfile_local git repository with fast-forward only' do
      Dir.mktmpdir do |dir|
        pull_status = stub(success?: true)
        rev_status = stub(success?: true)

        Command::Bin::Update.stubs(:detect_podfile_local_repo_dir).returns(dir)
        Open3.expects(:capture3).with('git', '-C', dir, 'pull', '--ff-only').returns(["Already up to date.\n", '', pull_status])

        Command::Bin::Update.update_podfile_local_repo!

        UI.output.should.include 'Already up to date.'
      end
    end

    it 'raises when Podfile_local is not in a git repo' do
      Command::Bin::Update.stubs(:detect_podfile_local_repo_dir).returns(nil)

      lambda do
        Command::Bin::Update.update_podfile_local_repo!
      end.should.raise(Informative)
    end
  end
end
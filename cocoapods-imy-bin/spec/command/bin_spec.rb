require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Bin do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ bin }).should.be.instance_of Command::Bin
      end
    end
  end
end


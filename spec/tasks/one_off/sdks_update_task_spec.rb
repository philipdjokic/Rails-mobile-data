require "rails_helper"
require '/varys/lib/tasks/one_off/sdks_update_task.rb'

describe SdksUpdateTask do

  describe ".perform" do
    let(:file_name) { 'test_file.csv' }
    let(:stream_name) { 'update_sdks' }
    let(:tag) { FactoryGirl.create(:tag, name: 'Wrong Tag')}
    let(:platform) { 'android' }
    let(:sdk) { FactoryGirl.create(:android_sdk, id: 1, name: 'Wrong Name') }
    
    before { sdk.tags << tag }
    
    context 'sdk found' do
      let(:file_content) { "ID,Category,New Website,New Name,New Summary\n1,Sports,http://sports.test.com,Sports Test,This is a test sport Sdk" }

      before :each do
        subject.perform(file_name, file_content, platform)
      end
  
      it { expect(AndroidSdk.find(sdk.id).name).to eq('Sports Test') }
      it { expect(AndroidSdk.find(sdk.id).tags.pluck(:name)).to eq(['Sports']) }
      it { expect(AndroidSdk.find(sdk.id).website).to eq('http://sports.test.com') }
      it { expect(AndroidSdk.find(sdk.id).summary).to eq('This is a test sport Sdk') }
    end

    context "catch error" do
      let(:sdk_id) { 2 }
      let(:file_content) { "ID,Category,New Website,New Name,New Summary\n#{sdk_id},Sports,http://sports.test.com,Sports Test,This is a test sport Sdk" }
      let(:firehose) { double(MightyAws::Firehose) }
  
      before :each do
        allow(Rails).to receive_message_chain(:logger, :error)
        allow(MightyAws::Firehose).to receive(:new).and_return(firehose)
        allow(firehose).to receive(:send).with(any_args)
        subject.perform(file_name, file_content, platform)
      end
  
      describe "sdk not exists" do
        it { expect(AndroidSdk.exists?(sdk_id)).to be false }
        it { expect(firehose).to have_received(:send).with(stream_name: stream_name, data: "#{file_name} = Sdk not found #{sdk_id}") }
      end
  
      describe "not android sdk" do
        let(:ios_sdk) { FactoryGirl.create(:ios_sdk, id: sdk_id, name: 'Wrong Name') }
  
        it { expect(AndroidSdk.exists?(sdk_id)).to be false }
        it { expect(firehose).to have_received(:send).with(stream_name: stream_name, data: "#{file_name} = Sdk not found #{sdk_id}") }
      end

      describe "not ios sdk" do
        let(:ios_sdk) { FactoryGirl.create(:android_sdk, id: sdk_id, name: 'Wrong Name') }
  
        it { expect(IosSdk.exists?(sdk_id)).to be false }
        it { expect(firehose).to have_received(:send).with(stream_name: stream_name, data: "#{file_name} = Sdk not found #{sdk_id}") }
      end
    end

  end

end
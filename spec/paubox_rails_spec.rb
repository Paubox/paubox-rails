require "spec_helper"

RSpec.describe PauboxRails do
  before do
    Paubox.configure do |config|
      config.api_key = 'test_key'
      config.api_user = 'test_user'
    end
  end

  let!(:client) { Paubox::Client.new }

  it "has a version number" do
    expect(PauboxRails::VERSION).not_to be nil
  end

  describe 'test mailer' do
    it 'should use Paubox for deliver' do
      allow(Paubox::Client).to receive(:new) { client }
      allow(client).to receive(:send_mail) do |message|
        expect(message.to.first).to eq("test@paubox.com")
      end
      TestMailer.text_only_message.deliver
    end
  end
end

require File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec_helper.rb')

describe APN::Notification do

  after do
    configatron.apn.auto_truncate = false
  end

  describe ".unsent_ids" do
    it "returns an array of unsent ids" do
      configatron.apn.auto_truncate = true
      device = DeviceFactory.create
      noty = APN::Notification.create(
        :device => device, :sound => true, :badge => nil
      )
      APN::Notification.unsent_ids.should include(noty.id)
      noty.destroy
      device.destroy
    end
  end

  describe 'alert' do

    it 'should trim the message to 130 characters' do
      noty = APN::Notification.new
      noty.alert = 'a' * 200
      noty.alert.should == ('a' * 127) + '...'
    end

  end

  describe 'apple_hash' do

    it 'should return a hash of the appropriate params for Apple' do
      noty = APN::Notification.first
      noty.apple_hash.should == {"aps" => {"badge" => 5, "sound" => "my_sound.aiff", "alert" => "Hello!"},"typ" => "1"}
      noty.custom_properties = nil
      noty.apple_hash.should == {"aps" => {"badge" => 5, "sound" => "my_sound.aiff", "alert" => "Hello!"}}
      noty.badge = nil
      noty.apple_hash.should == {"aps" => {"sound" => "my_sound.aiff", "alert" => "Hello!"}}
      noty.alert = nil
      noty.apple_hash.should == {"aps" => {"sound" => "my_sound.aiff"}}
      noty.sound = nil
      noty.apple_hash.should == {"aps" => {}}
      noty.sound = true
      noty.apple_hash.should == {"aps" => {"sound" => "1.aiff"}}
    end

  end

  describe 'to_apple_json' do

    it 'should return the necessary JSON for Apple' do
      noty = APN::Notification.first
      ActiveSupport::JSON.decode(noty.to_apple_json).should == ActiveSupport::JSON.decode(%{{"typ":"1","aps":{"badge":5,"sound":"my_sound.aiff","alert":"Hello!"}}})
    end

  end

  describe 'message_for_sending' do

    it 'should create a binary message to be sent to Apple' do
      noty = APN::Notification.first
      noty.custom_properties = nil
      noty.device = DeviceFactory.new(:token => '5gxadhy6 6zmtxfl6 5zpbcxmw ez3w7ksf qscpr55t trknkzap 7yyt45sc g6jrw7qz')

      expected = fixture_value('message_for_sending.bin').split("").sort
      actual   = noty.message_for_sending.split("").sort
      actual.should eq(expected)
    end

    it 'should raise an APN::Errors::ExceededMessageSizeError if the message is too big' do
      device = DeviceFactory.create
      noty = APN::Notification.create(:device => device, :sound => true, :badge => nil)
      noty.send(:write_attribute, 'alert', 'a' * 183)
      lambda {
        noty.message_for_sending
      }.should raise_error(APN::Errors::ExceededMessageSizeError)
    end

    it 'should not raise an expection if the message is too big if auto_truncate is enabled' do
      configatron.apn.auto_truncate = true
      device = DeviceFactory.create
      noty = APN::Notification.create(:device => device, :sound => true, :badge => nil)
      noty.send(:write_attribute, 'alert', 'a' * 183)
      lambda {
        noty.message_for_sending
      }.should_not raise_error
    end
  end

  describe 'send_notifications' do

    it 'should warn the user the method is deprecated and call the corresponding method on APN::App' do
      ActiveSupport::Deprecation.should_receive(:warn)
      APN::App.should_receive(:send_notifications)
      APN::Notification.send_notifications
    end
  end

end

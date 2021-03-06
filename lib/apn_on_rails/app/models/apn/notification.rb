# Represents the message you wish to send.
# An APN::Notification belongs to an APN::Device.
#
# Example:
#   apn = APN::Notification.new
#   apn.badge = 5
#   apn.sound = 'my_sound.aiff'
#   apn.alert = 'Hello!'
#   apn.device = APN::Device.find(1)
#   apn.save
#
# To deliver call the following method:
#   APN::Notification.send_notifications
#
# As each APN::Notification is sent the <tt>sent_at</tt> column will be timestamped,
# so as to not be sent again.
class APN::Notification < APN::Base
  include ::ActionView::Helpers::TextHelper
  extend ::ActionView::Helpers::TextHelper
  serialize :custom_properties

  belongs_to :device, :class_name => 'APN::Device'
  has_one    :app,    :class_name => 'APN::App', :through => :device

  def self.unsent
    self.find(:all, :conditions => {:sent_at => nil}, :joins => :device)
  end

  def self.unsent_ids
    self.find(:all, :conditions => {:sent_at => nil}, :select => :id).map(&:id)
  end

  # Stores the text alert message you want to send to the device.
  #
  # If the message is over 130 characters long it will get truncated
  # to 130 characters with a <tt>...</tt>
  def alert=(message, truncate_at = 130)
    if !message.blank? && message.size > truncate_at
      message = truncate(message, :length => truncate_at)
    end
    write_attribute('alert', message)
  end

  # Creates a Hash that will be the payload of an APN.
  #
  # Example:
  #   apn = APN::Notification.new
  #   apn.badge = 5
  #   apn.sound = 'my_sound.aiff'
  #   apn.alert = 'Hello!'
  #   apn.apple_hash # => {"aps" => {"badge" => 5, "sound" => "my_sound.aiff", "alert" => "Hello!"}}
  #
  # Example 2:
  #   apn = APN::Notification.new
  #   apn.badge = 0
  #   apn.sound = true
  #   apn.custom_properties = {"typ" => 1}
  #   apn.apple_hash # => {"aps" => {"badge" => 0, "sound" => "1.aiff"}, "typ" => "1"}
  def apple_hash(truncate_at = 130)
    result = {}
    result['aps'] = {}
    if self.alert
      result['aps']['alert'] = if self.alert.size > truncate_at
                                 truncate(self.alert, :length => truncate_at)
                               else
                                 self.alert
                               end
    end
    result['aps']['badge'] = self.badge.to_i if self.badge
    if self.sound
      result['aps']['sound'] = self.sound if self.sound.is_a? String
      result['aps']['sound'] = "1.aiff" if self.sound.is_a?(TrueClass)
    end
    if self.custom_properties
      self.custom_properties.each do |key,value|
        result["#{key}"] = "#{value}"
      end
    end
    result
  end

  # Creates the JSON string required for an APN message.
  #
  # Example:
  #   apn = APN::Notification.new
  #   apn.badge = 5
  #   apn.sound = 'my_sound.aiff'
  #   apn.alert = 'Hello!'
  #   apn.to_apple_json # => '{"aps":{"badge":5,"sound":"my_sound.aiff","alert":"Hello!"}}'
  def to_apple_json(truncate_at = 130)
    if truncate_at <= 80
      raise APN::Errors::TruncationFailure.new(self.id, self.alert)
    end
    json = self.apple_hash(truncate_at).to_json
    json = self.to_apple_json(truncate_at - 10) if json.length > 2048
    json
  end

  # Creates the binary message needed to send to Apple.
  def message_for_sending
    message = generate_message
    if message.size.to_i > 2048
      self.alert = self.alert[0,80] + "..."
    end
    message = generate_message
    raise APN::Errors::ExceededMessageSizeError.new(message) if message.size.to_i > 2048
    message
  end

  def generate_message
    json = self.to_apple_json
    length = [json.length, 255].min
    "\0\0 #{self.device.to_hexa}\0#{length.chr}#{json}"
  end

  def self.send_notifications
    ActiveSupport::Deprecation.warn("The method APN::Notification.send_notifications is deprecated.  Use APN::App.send_notifications instead.")
    APN::App.send_notifications
  end

end # APN::Notification

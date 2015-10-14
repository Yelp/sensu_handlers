#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"

class Hipchat < BaseHandler
  def handle
    case @event['action']
    when 'create'
      alert(true)
    when 'resolve'
      alert
    when 'flapping'
      true
    end
  end

  def api_key
    handler_settings['api_key'] || false
  end

  def event_time
    Time.at(@event['check']['issued']).utc.strftime "%Y-%m-%d %H:%M:%S UTC"
  end

  def check_notification_string
    @event['check']['notification'] || @event['check']['output']
  end

  def hipchat_message
    "<b>#{event_time} - #{@event['check']['name']} on #{@event['client']['name']} " +
      "(#{@event['client']['address']}) - #{human_check_status}</b><br />" +
    "<br />" +
    "&nbsp;&nbsp;#{check_notification_string}"
  end

  def hipchat_message_colour
    case @event['check']['status']
    when 0
      'green'
    when 1
      'yellow'
    when 2
      'red'
    else
      'grey'
    end
  end

  # hipchat prefers room before channel
  def channel_keys
    %w[ hipchat_room room channel ]
  end

  def pager_channel_keys
    %w[ hipchat_pager_room pager_room pager_channel ]
  end


  # hipchat message room api takes a notify option: 
  #
  # Whether this message should trigger a user notification (change the tab
  # color, play a sound, notify mobile phones, etc). Each recipient's
  # notification preferences are taken into account"
  #
  # https://www.hipchat.com/docs/apiv2/method/send_room_notification
  #
  # we use notify on normal alerts, but on resolve we just message the room
  # without extra notifications.  reduces noise.
  alias :rooms :channels
  def alert(notify = false)
    return false unless api_key

    rooms.each do |room|
      alert_hipchat(
        room,
        'sensu',
        hipchat_message,
        { 
          :color  => hipchat_message_colour,
          :notify => notify  # see note on notify above
        }
      )
    end

  end

  def hipchat_client
    require 'hipchat'
    @hipchat_client ||= HipChat::Client.new(api_key)
  end


  def alert_hipchat(room, sender, message, options_or_notify = {})
    # TODO handle failure to send,  such as bad room.
    timeout_and_retry do
      hipchat_client[room].send(sender, message, options_or_notify)
    end
  end
end

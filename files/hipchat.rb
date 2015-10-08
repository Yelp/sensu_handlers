#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"
#require_relative 'base'

class Hipchat < BaseHandler
  def handle
    timeout_and_retry do
      case check_data['status'].to_i
      when 1,2
        trigger_incident
      when 0
        resolve_incident
      end
    end
  end

  def api_key
    handler_settings['api_key'] || false
  end

  def trigger_incident
    alert(true)
  end

  def resolve_incident
    alert()
  end

  def event_time
    Time.at(check_data['issued']).utc.strftime "%Y-%m-%d %H:%M:%S UTC"
  end

  def check_notification_string
    check_data['notification'] || check_data['output']
  end

  def hipchat_message
    "<b>#{event_time} - #{check_data['name']} on #{client_data['name']} " +
      "(#{client_data['address']}) - #{human_check_status}</b><br />" +
    "<br />" +
    "&nbsp;&nbsp;#{check_notification_string}"
  end

  def hipchat_message_colour
    case check_data['status']
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


  alias :rooms :channels
  def alert(notify = false)
    return false unless api_key

    rooms.each do |room|
      alert_hipchat(
        room,
        'sensu',
        hipchat_message,
        { :color => hipchat_message_colour, :notify => notify }
      )
    end

  end


  def alert_hipchat(room, sender, message, options_or_notify = {})
    require 'hipchat'
    # TODO handle failure to send,  such as bad room.
    hipchat_client = HipChat::Client.new(api_key)
    hipchat_client[room].send(sender, message, options_or_notify)
  end
end

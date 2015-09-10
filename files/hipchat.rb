#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"
require 'hipchat'
#require_relative 'base'

class Hipchat < BaseHandler
  def handle
    timeout_and_retry do
      case @event['check']['status'].to_i
      when 1,2
        trigger_incident
      when 0
        resolve_incident
      end
    end
  end

  def api_key
    settings[self.class.name.downcase]['api_key'] || false
  end

  def trigger_incident
    return false unless api_key
    alert_hipchat(hipchat_room, 'sensu', hipchat_message, color: hipchat_message_colour, notify: true)
  end

  def resolve_incident
    return false unless api_key
    alert_hipchat(hipchat_room, 'sensu', hipchat_message, color: hipchat_message_colour)
  end

  def event_time
    Time.at(@event['check']['issued']).utc.to_s
  end

  def hipchat_message
"
<b>#{event_time} - #{@event['check']['name']} on #{@event['client']['name']} (#{@event['client']['address']}) - #{human_check_status}</b>
<br /><br />
&nbsp;&nbsp;#{@event['check']['notification'] || @event['check']['output']}
"
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

  def default_room
    settings[self.class.name.downcase]['hipchat_room']
  end

  def hipchat_room
    team_data('hipchat_room') || default_room || nil
  end 

  def alert_hipchat(room, sender, message, options_or_notify = {})
    return false unless api_key

    # TODO handle failure to send,  such as bad room.
    hipchat_client = HipChat::Client.new(api_key)
    hipchat_client[room].send(sender, message, options_or_notify)
  end
end

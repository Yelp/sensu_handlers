#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"
require 'hipchat'
#require_relative 'base'

class Hipchat < BaseHandler
  def handle
    response = timeout_and_retry do
      case @event['check']['status'].to_i
      when 1,2
        trigger_incident
      when 0
        resolve_incident
      end
    end
  end

  def api_key
    settings[self.class.name.downcase]['apikey'] || false
  end

  def trigger_incident
    alert_hipchat(color: hipchat_message_colour, notify: true)
  end

  def resolve_incident
    alert_hipchat(color: hipchat_message_colour)
  end

  def hipchat_message
"
<b>#{Time.at(@event['check']['issued'])} - #{@event['check']['name']} on #{@event['client']['name']} (#{@event['client']['address']}) - #{human_check_status}</b>
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

  def hipchat_room
    team_data('hipchat_room') || false
  end

  def alert_hipchat(options_or_notify = {})
    return false unless api_key

    hipchat_client = HipChat::Client.new(api_key)
    hipchat_client[hipchat_room].send('sensu', hipchat_message, options_or_notify)
  end
end

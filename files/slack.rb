#!/usr/bin/env ruby

require "json"
require "net/http"
require "#{File.dirname(__FILE__)}/base"

class Slack < BaseHandler
  def slack_url
    handler_settings['webhook_url']
  end

  def pages_slack_channel
    team_data('pages_slack_channel') || "##{team_name}-pages"
  end

  def compact_messages
    team_data('slack_compact_message') || false
  end

  def channels
    channels = []
    # All pages get to the pages_slack_channel
    if should_page?
      channels.push pages_slack_channel
    end
    # Allow slack_channels override if specified in the check itself
    if @event['check']['slack_channels']
      channels.push @event['check']['slack_channels']
    else
      team_data('notifications_slack_channel') { |channel| channels.push channel }
    end

    channels
  end

  def message
    # Slack provides a few color presets for situations like these
    # There's no specific reason for using them here, except that they seem
    # like sane defaults. There's no reason not to override them if you want!
    case @event['check']['status']
    when 0
      status = 'OK'
      color  = 'good'
    when 1
      status = 'WARNING'
      color = 'warning'
    when 2
      status = 'CRITICAL'
      color = 'danger'
    else
      status = 'UNKNOWN'
      color = '#aaaaaa'
    end

    message_fields = [
      {
        "title" => "Hostname",
        "value" => client_display_name,
        "short" => true
      },
      {
        "title" => "Check",
        "value" => @event['check']['name'],
        "short" => true
      },
      {
        "title" => "Status",
        "value" => status,
        "short" => true
      }
    ]

    if event_is_critical? or event_is_warning?
      message_fields << {
        "title" => "Runbook",
        "value" => "#{runbook}",
        "short" => true
      }
    end

    message_fields << {
      "title" => "Check Output",
      "value" => "```#{@event['check']['output']}```",
      "short" => false
    }

    if event_is_critical? or event_is_warning?
      message_fields << {
        "title" => "Tip",
        "value" => tip,
        "short" => false
      }
    end

    expanded_msg = {
      "username"    => "Sensu",
      "attachments" => [
        {
          "color"    => color,
          "fallback" => description(maxlen=400),
          "fields"   => message_fields,
          "footer"   => Socket.gethostname,
          "ts"       => Time.now.utc.to_f
        }
      ]
    }

    compact_msg = {
      "username" => "Sensu (#{Socket.gethostname.split('.')[0]})",
      "text"     => description(maxlen=400)
    }

    if compact_messages
      compact_msg
    else
      expanded_msg
    end
  end

  def handle
    channels.each do |channel|
      post_to_slack(channel, message)
    end
  end

  def post_to_slack(channel, msg)
    msg['channel'] = channel
    webhook_url = slack_url
    uri = URI(webhook_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = msg.to_json
    http.request request
  end

end

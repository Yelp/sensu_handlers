#!/usr/bin/env ruby
#
# Opsgenie handler which creates and closes alerts. Based on the pagerduty
# handler.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require "net/https"
require "uri"
require "json"

require "#{File.dirname(__FILE__)}/base"

class Opsgenie < BaseHandler

  def handle
    if !should_page? # Explicitly check for true. We don't page by default.
      puts "Opsgenie handler -- Ignoring incident " + @event['check']['name']  + 'as it is not set to page.'
      return
    end

    # Fail fast if we don't have the right data to work with
    return false unless api_key
    return false unless recipients

    begin
      timeout(3) do
        response = case @event['check']['status'].to_i
                   when 2
                     action = 'trigger'
                     create_alert
                   when 0,1
                     action = 'resolve'
                     close_alert
                   end
        if response
          puts 'opsgenie -- ' + action + 'd incident -- ' + event_id
        else
          puts 'opsgenie -- failed to ' + action + ' incident -- ' + event_id
        end
      end
    rescue Timeout::Error
      puts 'opsgenie -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + event_id
    end
  end

  def event_id
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def event_status
    @event['check']['status']
  end

  def close_alert
    post_to_opsgenie(:close, {:alias => event_id})
  end

  def api_key
    team_data('opsgenie_api_key') || false
  end

  def recipients
    team_data('opsgenie_recipients') || false
  end

  def create_alert
    tags = []
    tags << "unknown" if event_status >= 3
    tags << "critical" if event_status == 2
    tags << "warning" if event_status == 1

    post_to_opsgenie(:create, {:alias => event_id, :message => description, :tags => tags.join(","), :details => full_description_hash })
  end

  def post_to_opsgenie(action = :create, params = {})
    params["customerKey"] = api_key
    params["recipients"]  = recipients

    uripath = (action == :create) ? "" : "close"
    uri = URI.parse("https://api.opsgenie.com/v1/json/alert/#{uripath}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' =>'application/json'})
    request.body = params.to_json
    response = http.request(request)
    if response.code == '200'
      return true
    else
      puts "Uh oh. Got a return code of " + response.code
      puts response
      return false
    end
  end

end

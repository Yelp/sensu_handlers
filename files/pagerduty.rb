#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"

class Pagerduty < BaseHandler
  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def api_key
    team_data('pagerduty_api_key') || false
  end

  def timeout_and_retry(&block)
    response = false
    3.times do
      begin
        timeout(10) do
          response = block
          return true if response == 'success'
        end
      rescue Timeout::Error
      end
      sleep 3
    end
    response
  end

  def trigger_incident
    return false unless api_key
    require 'redphone/pagerduty'
    status = timeout_and_retry do
      Redphone::Pagerduty.trigger_incident(
        :service_key  => api_key,
        :incident_key => incident_key,
        :description  => description,
        :details      => full_description_hash
      )['status']
    end
    status
  end

  def resolve_incident
    return false unless api_key
    require 'redphone/pagerduty'
    status = timeout_and_retry do
      status = Redphone::Pagerduty.resolve_incident(
        :service_key  => api_key,
        :incident_key => incident_key
      )['status']
    end
    status
  end

  def handle
    if !should_page? # Explicitly check for true. We don't page by default.
      puts "pagerduty -- Ignoring incident #{incident_key} as it is not set to page."
      return
    end
    action = 'nil'
    response = case @event['check']['status'].to_i
    when 2
      action = 'trigger'
      trigger_incident
    when 0,1
      action = 'resolve'
      resolve_incident
    end
    if response
      puts 'pagerduty -- ' + action.capitalize + 'd incident -- ' + incident_key
    else
      puts 'pagerduty -- failed to ' + action + ' incident -- ' + incident_key
    end
  end

end


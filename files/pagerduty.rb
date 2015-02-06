#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"

class Pagerduty < BaseHandler
  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def api_key
    team_data('pagerduty_api_key') || false
  end

  def trigger_incident
    return false unless api_key
    require 'redphone/pagerduty'
    Redphone::Pagerduty.trigger_incident(
      :service_key  => api_key,
      :incident_key => incident_key,
      :description  => description,
      :details      => full_description_hash
    )['status'] == 'success'
  end

  def resolve_incident
    return false unless api_key
    require 'redphone/pagerduty'
    Redphone::Pagerduty.resolve_incident(
      :service_key  => api_key,
      :incident_key => incident_key
    )['status'] == 'success'
  end

  def log(line)
    puts line
  end

  def handle
    if !should_page? # Explicitly check for true. We don't page by default.
      log "pagerduty -- Ignoring incident #{incident_key} as it is not set to page."
      return
    end
    begin
      timeout(10) do
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
          log 'pagerduty -- ' + action.capitalize + 'd incident -- ' + incident_key
        else
          log 'pagerduty -- failed to ' + action + ' incident -- ' + incident_key
        end
      end
    rescue Timeout::Error
      log 'pagerduty -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end
end


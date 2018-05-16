#!/usr/bin/env ruby
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'timeout'

# Taken from https://github.com/flori/term-ansicolor/blob/e6086b7fddf53c53f8022acc1920f435e65b5e51/lib/term/ansicolor.rb#L60
COLOR_REGEX = /\e\[(?:(?:[349]|10)[0-7]|[0-9]|[34]8;5;\d{1,3})?m/

class BaseHandler < Sensu::Handler
  def deprecated_filtering_enabled?
    true
  end

  def deprecated_occurrence_filtering_enabled?
    true
  end

  def event_is_ok?
    @event['check']['status'] == 0
  end

  def event_is_critical?
    @event['check']['status'] == 2
  end

  def event_is_warning?
    @event['check']['status'] == 1
  end

  def human_check_status
    case @event['check']['status']
    when 0
      'OK'
    when 1
      'WARNING'
    when 2
      'CRITICAL'
    else
      'UNKNOWN'
    end
  end

  def uncolorize(input)
    input.gsub(COLOR_REGEX, '')
  end

  def should_page?
    @event['check']['page'] || false
  end

  def runbook
    @event['check']['runbook'] || false
  end

  def event_description
    @event['check']['description'] || 'N/A'
  end

  def component
    "[" << Array(@event['check']['component'] || []).join(',') << "]"
  end

  def team_name
    if @event['check']['team'] then
      @event['check']['team']
    else
      bail "check did not provide a team name"
    end
  end

  def team_data(lookup_key = nil)
    return unless team_name
    data = handler_settings['teams'][team_name] || {}
    if lookup_key
      data = data[lookup_key]
    end
    yield(data) if data && block_given?
    data
  end

  def tip
    @event['check']['tip']
  end

  def client_display_name(with_instance_id=false)
    client_display_name = @event['client']['tags']['Display Name'] rescue nil
    client_display_name = @event['client']['name'] if
      client_display_name.nil? || client_display_name.empty?
    if with_instance_id
      instance_id = @event['client']['instance_id'] rescue nil
      client_display_name += " (#{instance_id})" if instance_id
    end
    client_display_name
  end

  def description(maxlen=100000, uncolorize=true)
    description = @event['check']['notification']

    message_parts = [client_display_name, @event['check']['name']]
    if uncolorize
      message_parts.push(uncolorize(@event['check']['output']))
    else
      message_parts.push(@event['check']['output'])
    end

    description ||= message_parts.join(' : ')
    if event_is_critical? or event_is_warning?
      toadd = ""
      if tip
        toadd = "#{toadd} - #{tip}"
      end
      if runbook
        toadd = "#{toadd} (#{runbook})"
      end
      description = "#{description}#{toadd}"
    end
    description.gsub("\n", ' ')[0..maxlen-1]
  end

  def full_description

    body = <<-BODY
#{uncolorize(@event['check']['output'])}

Dashboard Link: #{dashboard_link}
Runbook: #{runbook}
Tip: #{tip}

Command:  #{@event['check']['command']}
Status: #{human_check_status()} (#{@event['check']['status']})

Timestamp: #{Time.at(@event['check']['issued'])}
Occurrences:  #{@event['occurrences']}

Team: #{team_name}
Host: #{client_display_name(true)}
Client Name: #{@event['client']['name']}
Address:  #{@event['client']['address']}
Check Name:  #{@event['check']['name']}
Description: #{event_description}
Component: #{component}

BODY
    body
  end

  def jira_description

    body = <<-BODY
{code}
#{uncolorize(@event['check']['output'])}
{code}

Dashboard Link: #{dashboard_link}
Runbook: #{runbook}
Tip: #{tip}

Command: {{#{@event['check']['command']}}}
Status: #{human_check_status()} (#{@event['check']['status']})

Timestamp: #{Time.at(@event['check']['issued'])}
Occurrences:  #{@event['occurrences']}

Team: #{team_name}
Host: {{#{client_display_name(true)}}}
Client Name: {{#{@event['client']['name']}}}
Address:  #{@event['client']['address']}
Check Name:  #{@event['check']['name']}
Description: #{event_description}
Component: #{component}

BODY
    body
  end


  def full_description_hash
    {
      'Output' => uncolorize(@event['check']['output']),
      'Dashboard Link' => dashboard_link,
      'Host' => @event['client']['name'],
      'Timestamp' => Time.at(@event['check']['issued']),
      'Address' => @event['client']['address'],
      'Check Name' => @event['check']['name'],
      'Command' => @event['check']['command'],
      'Status' => "#{human_check_status()} (#{@event['check']['status']})",
      'Occurrences' => @event['occurrences'],
      'Team' => team_name,
      'Runbook' => runbook,
      'Tip' => tip,
      'Server' => Socket.gethostname,
      'description' => event_description,
      'component' => component,
    }

  end

  def dashboard_link
    settings['default']['dashboard_link'].gsub(/\/$/, '')
    "#{settings['default']['dashboard_link']}/#/client/#{datacenter}/#{@event['client']['name']}?check=#{@event['check']['name']}" || 'Unknown dashboard link. Please set for the base handler config'
  end

  def datacenter
    settings['default']['datacenter']
  end

  def log(line)
    puts line
  end

  def do_sleep
    sleep 3
  end

  def timeout_and_retry(&block)
    2.times do
      begin
        timeout(10) do
          return true if block.call
        end
      rescue Timeout::Error
      end
      do_sleep
    end
    timeout(10) do
      block.call
    end
  end

  # == Custom Yelp Filter Logic
  # We have multiple output handlers and routing logic, and we to ensure
  # that both active and passive checks and take advantage of it
  # Addionally we want to simplify the timing logic as much as possible.
  #
  # To that end we take the following event data to determine if we should
  # create an alert or not:
  #
  def filter_repeated
    reset_api_settings!
    if @event['check']['name'] == 'keepalive'
      # Keepalives are a special case because they don't emit an interval.
      # They emit a heartbeat every 20 seconds per
      # http://sensuapp.org/docs/0.12/keepalives
      interval = 20
    else
      interval      = @event['check']['interval'].to_i || 0
    end
    alert_after   = @event['check']['alert_after'].to_i || 0

    if self.class.name =~ /Pagerduty/ && @event['check']['page_after']
      alert_after = @event['check']['page_after'].to_i
    end

    # nil.to_i == 0
    # 0 || 1   == 0
    realert_every = ( @event['check']['realert_every'] || 1 ).to_i 
    # realert_every can't be 0 because of potential ZeroDivisionError below
    realert_every = -1 if realert_every == 0

    initial_failing_occurrences = interval > 0 ? (alert_after / interval) : 0
    number_of_failed_attempts = @event['occurrences'] - initial_failing_occurrences

    # sensu 0.26+ only, else never make  occurrences_watermark actionable
    # https://github.com/Yelp/sensu_handlers/issues/103
    # this hack takes care of scenario
    # when event has triggered at action == create
    # but did not resolve the corresponding event when action == resolve.
    # occurrences_watermark > initial_failing_occurrences prove enough occurrences
    # of the event that triggered create and hence it is safe to filter the event to resolve handler action.
    if (@event.key?('occurrences_watermark') &&
        @event['occurrences_watermark'] > initial_failing_occurrences &&
        @event['action'] == 'resolve')
      return
    end

    # Don't bother acting if we haven't hit the 
    # alert_after threshold
    if number_of_failed_attempts < 1
      bail "Not failing long enough, only #{number_of_failed_attempts} after " \
        "#{initial_failing_occurrences} initial failing occurrences"
    # If we have an interval, and this is a creation event, that means we are
    # an active check
    # Lets also filter based on the realert_every setting
    elsif interval > 0 and @event['action'] == 'create' 
      # Special case of exponential backoff
      if realert_every == -1
        # If our number of failed attempts is an exponent of 2
        if power_of_two?(number_of_failed_attempts)
          # Then This is our MOMENT!
          return nil
        else
          bail "not on a power of two: #{number_of_failed_attempts}"
        end
      elsif (number_of_failed_attempts - 1) % realert_every != 0
        # Now bail if we are not in the realert_every cycle
        bail "only handling every #{realert_every} occurrences, and we are at" \
          " #{number_of_failed_attempts}"
      end
    end
  end

  def power_of_two?(x)
    while ( x % 2) == 0 and x > 1
      x /= 2
    end
    x==1
  end

  def settings_key
    self.class.name.downcase
  end

  def handler_settings
    settings[settings_key]
  end

  def reset_api_settings!
    @settings['api'].merge!(settings['api_client']) if settings['api_client']
  end

  ##################################
  ## channels helper for chat handlers
  def channel_keys
    %w[ channel room ]
  end

  def pager_channel_keys
    %w[ pager_channel pager_room ]
  end

  def default_pager_channel
    "#{team_name}-pages"
  end

  def default_pager
    return [] if handler_settings['use_default_pager'] == false
    default_pager_channel
  end

  def find_channel(keys, &block)
    keys \
      .map(&block) \
      .detect { |item| item } # first non nil/false item
  end

  def event_channel(keys = channel_keys)
    find_channel(keys) { |key| @event['check'][key] }
  end

  def team_channel(keys = channel_keys)
    find_channel(keys) { |key| team_data(key) }
  end

  def event_pager_channel
    event_channel(pager_channel_keys)
  end

  def team_pager_channel
    team_channel(pager_channel_keys) || default_pager
  end

  def notifications_channel
    event_channel || team_channel || []
  end

  def pager_channel
    event_pager_channel || team_pager_channel || []
  end

  def channels
    channels = []
    channels.push pager_channel if should_page?
    channels.push notifications_channel
    channels.flatten
  end
  ## end channels helper
  #####################################

  def redis
    return @redis if @redis

    $: << '/etc/sensu/plugins'
    require 'tiny_redis'
    redis_config = JSON.parse(
      File.open('/etc/sensu/conf.d/redis.json') { |f| f.read })
    @redis = TinyRedis::Client.new(host=redis_config['redis']['host'],
                                     port=redis_config['redis']['port'])
    rescue => e
      raise "Unable to load redis client or connect to sensu redis: #{e.message}"
  end

  def timeout(t)
    Timeout.timeout(t) { yield }
  end

end


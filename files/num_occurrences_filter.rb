#
# This code will run inside sensu-server process. Be careful with external calls
# that could disrupt event loop.
#
module Sensu::Extension
  class NumOccurrences < Filter

    STOP_PROCESSING  = 0
    ALLOW_PROCESSING = 1

    def name
      'num_occurrences_filter'
    end

    def description
      'filter events based on the number of occurrences'
    end

    def run(event)
      begin
        rc, msg = filter_by_num_occurrences(event)
        yield msg, rc
      rescue => e
        # filter crashed - let's pass this on to handler
        yield e.message, ALLOW_PROCESSING
      end
    end

    # This used to be in base.rb but was moved into a sensu extension
    # to avoid forking handlers for events which they are not going to handle.
    #
    # There are no external calls here, only math.
    #
    # == Custom Yelp Filter Logic
    # We have multiple output handlers and routing logic, and we to ensure
    # that both active and passive checks and take advantage of it
    # Addionally we want to simplify the timing logic as much as possible.
    #
    # To that end we take the following event data to determine if we should
    # create an alert or not:
    #
    def filter_by_num_occurrences(event)
      if event[:check][:name] == 'keepalive'
        # Keepalives are a special case because they don't emit an interval.
        # They emit a heartbeat every 20 seconds per
        # http://sensuapp.org/docs/0.12/keepalives
        interval = 20
      else
        interval = event[:check][:interval].to_i || 0
      end
      alert_after = event[:check][:alert_after].to_i || 0

      # nil.to_i == 0
      # 0 || 1   == 0
      realert_every = ( event[:check][:realert_every] || 1 ).to_i

      initial_failing_occurrences = interval > 0 ? (alert_after / interval) : 0
      number_of_failed_attempts = event[:occurrences] - initial_failing_occurrences

      # Don't bother acting if we haven't hit the alert_after threshold
      if number_of_failed_attempts < 1
        return STOP_PROCESSING, strip(%Q{
          Not failing long enough, only #{number_of_failed_attempts} after
          #{initial_failing_occurrences} initial failing occurrences
        })
      # If we have an interval, and this is a creation event, that means we are
      # an active check
      # Lets also filter based on the realert_every setting
      elsif interval > 0 and event[:action] == :create
        # Special case of exponential backoff
        if realert_every == -1
          # If our number of failed attempts is an exponent of 2
          if power_of_two?(number_of_failed_attempts)
            # Then This is our MOMENT!
            return ALLOW_PROCESSING, "can be processed now: #{number_of_failed_attempts}"
          else
            return STOP_PROCESSING,
                   "not on a power of two: #{number_of_failed_attempts}"
          end
        elsif (number_of_failed_attempts - 1) % realert_every != 0
          # Now bail if we are not in the realert_every cycle
          return STOP_PROCESSING, strip(%Q{
            only handling every #{realert_every} occurrences, and we are at
            #{number_of_failed_attempts}
          })
        end
      end

      # if we reached here, we didn't find any reason to block processing
      return ALLOW_PROCESSING, 'the end'
    end

    def power_of_two?(x)
      return false if x > 1 && x.odd?
      while ( x % 2) == 0 and x > 1
        x /= 2
      end
      x==1
    end

    def strip(s)
      s.strip.gsub(/[\s\n]+/, ' ')
    end

  end

  class NumOccurrencesForPagerdutyHandler < NumOccurrences

    def name
      'num_occurrences_filter_for_pagerduty'
    end

    def description
      'filter events based on the number of occurrences for pagerduty handler'
    end

    def run(event)
      begin
        # this requires deep merge;
        # this is a workaround instead of getting extra libs
        modified_event = Marshal.load(Marshal.dump(event))
        modified_event[:check][:alert_after] = event[:check][:page_after] if
          event[:check][:page_after]
        rc, msg = filter_by_num_occurrences(modified_event)
        yield msg, rc
      rescue => e
        # filter crashed - let's pass this on to handler
        yield e.message, ALLOW_PROCESSING
      end
    end

  end

end

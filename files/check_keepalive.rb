module Sensu
module Extension

# 1) update per-check timestamps in redis
# 2) have eventmachine periodic timer to check if anything timed out and
#    generate a new "critical" event for every
#
# extension has access to:
#  - logger     @logger
#  - redis      @settings[:redis]
#  - transport  @settings[:transport]

class CheckKeepalive < Handler
  def name
    'check_keepalive'
  end

  def description
    'emit per-check keepalive events'
  end

  def post_init
    @redis    = @settings.redis
    @em_timer = EventMachine::PeriodicTimer.new(10) { process_keepalives }
  end

  def stop
    @em_timer.cancel
    yield
  end

  def run(event)
    client_name = event[:client][:name]
    check_name  = event[:check][:name]

    rkey = "ext:check_keepalive:checks"
    hkey = "#{client_name}:#{check_name}"
    hval = event[:check][:keepalive]
    args = hval ? [:hset, rkey, hkey, hval] : [:hdel, rkey, hkey]

    @redis.send(*args) { yield }
  rescue => e
    @logger.error 'Exception in CheckKeepalive#run'
    @logger.error e
  end

  private

  def process_keepalives
    @logger.info('determining stale checks')
    @redis.hgetall("ext:check_keepalive:checks") do |clients_checks|
      clients_checks.each do |client_check, keepalive|
        # possibly we should attempt to load check info here and double-check
        # it has to be keepalived?
        @logger.debug("checking staleness of #{client_check}")

        @redis.get("execution:#{client_check}") do |time|
          next unless time

          seconds_ago = Time.now.to_i - time.to_i
          next if seconds_ago < keepalive

          emit_critical(client_check, seconds_ago) if seconds_ago > keepalive.to_i
        end
      end
    end
  rescue => e
    @logger.error 'Exception in CheckKeepalive#process_keepalives'
    @logger.error e
  end

  def emit_critical(client_check, stale_for)
    client, check_name = client_check.split ':'

    check = {
      :name   => check_name,
      :status => 2,
      :issued => Time.now.to_i,
      :output => "Watchdog timer expired. Haven't heard any output " <<
                 "for this check in #{stale_for} seconds." }

    payload = { :client => client, :check => check }

    @logger.debug('publishing check keepalive', {:payload => payload})
    @settings[:transport].publish(:direct, 'results', MultiJson.dump(payload)) do |info|
      if info[:error]
        @logger.error('failed to publish check keepalive', {
          :payload => payload,
          :error => info[:error].to_s
        })
      end
    end
  end
end

end
end

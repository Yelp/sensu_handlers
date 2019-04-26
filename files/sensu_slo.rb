#!/usr/bin/env ruby
#
# Sensu Handler: sensu_slo
#
# This handler calculate the age of a check by subtracting the execution
# time of the check with the current time on the Sensu server. This can
# be used to monitor check latency and also, by evaluating the interval
# time, used to give and idea of the number of succesfull checks
# navigating Sensu's message bus.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'socket'

$env_dir = "/nail/etc/"

class SensuSLOHandler < Sensu::Handler

  def handle

    $metric_name = settings['sensu_slo']['metric_name'] || 'sensu.check_age'

    statsite_host = settings['sensu_slo']['statsite_host'] || '127.0.0.1'
    statsite_port = settings['sensu_slo']['statsite_port'] || 8125

    # Get hostname of this Sensu server
    begin
        $hostname = Socket.gethostname
    rescue => _e
        STDERR.print "Could not determine hostname: #{e}"
        exit 1
    end

    # Check required check fields are available
    if @event["check"].nil?
      STDERR.print "Check result does not appear to contain check data"
      exit 1
    end

    if @event["check"]["name"].nil?
      STDERR.print "Check result did not have a 'name'"
      exit 1
    end

    if @event["client"]["name"].nil?
      STDERR.print "Check result did not have a 'client name'"
      exit 1
    end

    # Calculate how long ago the check was executed
    now = Time.now.to_i
    executed = @event["check"]["executed"].to_i
    if executed == nil
      STDERR.puts "Check result does not have an 'executed' field"
      exit 1
    end
    age = now - executed

    # Get a sorted json serialized multi-dimensional array of statsite dimensions
    dims = create_dimensions_json

    # Format the output string and send to statsite
    statsite_msg = "#{dims}:#{age}|g"

    statsite = UDPSocket.new
    n = statsite.send statsite_msg, 0, statsite_host, statsite_port

    STDERR.print "Zero bytes sent to #{statsite_host}:#{statsite_port}. Msg: #{statsite_msg}" if n < 1
    STDOUT.print "#{n} bytes sent to #{statsite_host}:#{statsite_port}: #{statsite_msg}"

    exit 0

  end

  def create_dimensions_json

    # Extract the name of the check and the client which ran it
    check_name = @event["check"]["name"]
    client_name = @event["client"]["name"]

    # Create an array to hold the metric Dimensions
    dims = Array.new
    dims << ["metric_name", $metric_name]

    # Add default environment Dimensions
    begin
      dims << ["habitat", File.read($env_dir + "/habitat").strip]
    rescue Errno::ENOENT
      STDERR.puts "Could not read #{f}"
      exit 1
    rescue => e
      STDERR.puts "An unknown error occured: #{e}"
      exit 1
    end

    # Add the check specific dimensions
    dims << ["check_name", check_name]
    dims << ["client_name", client_name]
    dims << ["hostname", $hostname]

    # Sort dimensions alphabetically by dimension name to ensure consitent keying
    dims.sort! {|a,b| a[0] <=> b[0]}

    begin
      dims_json = dims.to_json
    rescue => e
      STDERR.print "Could not create dimensions JSON: #{e}"
      exit 1
    end

    return dims_json

  end

end

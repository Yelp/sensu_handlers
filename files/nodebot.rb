#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"

class Nodebot < BaseHandler
  def pages_irc_channel
    team_data('pages_irc_channel') || "##{team_name}-pages"
  end

  def channels
    channels = []
    # All pages get to the pages_irc_channel
    if should_page?
      channels.push pages_irc_channel
    end
    # Allow irc_channels override if specified in the check itself
    if @event['check']['irc_channels']
      channels.push @event['check']['irc_channels']
    else
      team_data('notifications_irc_channel') { |channel| channels.push channel }
    end
    # Return channels, but strip out any "#", nodebot doesn't need them
    channels.flatten.uniq.collect { |x| x.gsub(/#/, '') }
  end

  def message
    case @event['check']['status']
    when 0
      status = 'OK'
      color  = '9'
    when 1
      status = 'WARNING'
      color = '8'
    when 2
      status = 'CRITICAL'
      color = '4'
    else
      status = 'UNKNOWN'
      color = '7'
    end

    # Max irc line length is ~ 419, from:
    # [sensu]  CRITICAL - relengsrv2-devc.dev.yelpcorp.com : mom_to_iad1 : CheckRabbitFederation CRITICAL: Link not running: {"uri"=>"amqp://mommq1.local-iad1.yelpcorp.com/MOM", "timestamp"=>"2014-08-21 8:29:05", "node"=>"rabbit@sysinfra2-r1-devc", "exchange"=>"amq.direct", "type"=>"exchange", "upstream_exchange"=>"amq.direct", "status"=>"starting", "upstream"=>"mom_to_iad1", "vhost"=>"MOM"}  - Bounce cluster if links di

    pre = "[sensu] #{color} #{status} - "
    "#{pre}#{description(415 - pre.length)}"
  end

  def handle
    channels.each do |channel|
      send(channel, message)
    end
  end

  def send(channel, message)
    system('/nail/sys/bin/nodebot', channel, message)
  end
end


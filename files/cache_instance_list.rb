#!/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'fog'
require 'json'
require 'sensu-plugin/check/cli'
require 'fileutils'

class Instance_list < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => true

  option :aws_secret_access_key,
    :short => '-k AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => true

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  def write_instance_cache(instance_list)
    bail if instance_list.nil?
    f = File.open('/var/cache/instance_list.json.new', 'w')  { |f|  f.write(instance_list.to_json) }
    FileUtils.mv('/var/cache/instance_list.json.new', '/var/cache/instance_list.json')
  end

  def ec2
    @ec2 ||= begin
      Fog::Compute.new({
        :provider => 'AWS',
        :aws_access_key_id      => config[:aws_access_key],
        :aws_secret_access_key  => config[:aws_secret_access_key],
        :region                 => config[:aws_region]
      })
    end
  end

  def run
    running_instances = ec2.servers.reject { |s| s.state == 'terminated' }
    write_instance_cache(running_instances)
    ok
  end

end


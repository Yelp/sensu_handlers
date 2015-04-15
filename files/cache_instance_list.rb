#!/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'fog'
require 'sensu-plugin/check/cli'
require 'fileutils'
require 'yaml'

class Instance_list < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => false

  option :aws_secret_access_key,
    :short => '-k AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => false

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  option :credential_file,
    :short => '-f credential_file',
    :long => '--credential-file credential_file',
    :description => 'fog credential file',
    :required => false

  def write_instance_cache(instance_list)
    bail if instance_list.nil?
    f = File.open('/var/cache/instance_list.json.new', 'w')  { |f|  f.write(instance_list.to_json) }
    FileUtils.mv('/var/cache/instance_list.json.new', '/var/cache/instance_list.json')
  end

  def ec2
    @ec2 ||= begin
      opts = { :provider => 'AWS', :region => config[:aws_region] }
      if config[:credential_file]
        Fog.credentials_path = config[:credential_file]
      elsif config[:aws_access_key] && config[:aws_secret_access_key]
        opts.merge! :aws_access_key_id      => config[:aws_access_key],
                    :aws_secret_access_key  => config[:aws_secret_access_key]
      end
      Fog::Compute.new opts
    end
  end

  def run
    running_instances = ec2.servers.reject { |s| s.state == 'terminated' }
    write_instance_cache(running_instances)
    ok
  end

end

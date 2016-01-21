#!/opt/puppet-omnibus/embedded/bin/ruby

# Delete all terminated or missing AWS clients from sensu
#
# 1. Read Sensu API creds from /etc/sensu/conf.d/api.json
# 2. Get Sensu clients that have a valid instance_id
# 3. Read AWS creds from /etc/sensu/cache_instance_list_creds.yaml
# 4. Get AWS instance_id list
# 5. Find a diff between two lists
# 6. Delete all sensu clients listed in diff (but avoid deleting all sensu clients)
#

require 'trollop'
require 'logger'
require 'net/http'
require 'json'
require 'aws-sdk'
require 'aws-sdk-resources'

PATH_SENSU_API_JSON = '/etc/sensu/conf.d/api.json'
PATH_SENSU_CLI_CFG = '/etc/sensu/sensu-cli/settings.rb'
PATH_AWS_API_JSON = '/etc/sensu/cache_instance_list_creds.yaml'
PATH_LOG_FILE = '/tmp/.delete_terminated_ec2_clients.log'

class SensuApiConnector

  def initialize(logger=nil)
    if logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
    else
      @logger = logger
    end

    @settings = settings

    @sensu_http = Net::HTTP.new(@settings[:host], @settings[:port])
    @sensu_http.open_timeout = 2
  end

  def settings
    @logger.debug("Reading #{PATH_SENSU_CLI_CFG} ..")
    s = _read_sensu_cli_cfg rescue nil
    if s.nil?
      @logger.debug("Failed to read #{PATH_SENSU_CLI_CFG}.")
      @logger.debug("Reading #{PATH_SENSU_API_JSON} ..")
      s = _read_sensu_api_cfg rescue nil
      @logger.debug("Failed to read #{PATH_SENSU_API_JSON}.")
    end
    s
  end

  def _read_sensu_cli_cfg
    s = File.open(PATH_SENSU_CLI_CFG, 'r').read
    {
      :host => s[/host\s+'(.*)'/, 1],
      :port => s[/port\s+'([0-9]+)'/, 1].to_i,
      :user => s[/user\s+'(\w+)'/, 1],
      :password => s[/password\s+'(.*)'/, 1],
    }
  end

  def _read_sensu_api_cfg
    c = JSON.load(File.open(PATH_SENSU_API_JSON, 'r'))
    if !c.nil? and c.has_key?('api')
      c = c['api']
      { :host => c['host'], :port => c['port'],
        :user => c['user'], :password => c['password'] }
    end
  end

  def send_http_request(request)
    request.basic_auth @settings[:user], @settings[:password]
    response = nil
    begin
      response = @sensu_http.request request # Net::HTTPResponse object
    rescue Net::OpenTimeout, SocketError => e
      @logger.fatal("Can't connect to Sensu API (#{request.uri}): #{e.message}")
    end
    response
  end

  def get_clients_with_instance_id
    @logger.debug('Retrieving clients list from Sensu API.')
    request = Net::HTTP::Get.new URI("http://#{@settings[:host]}:#{@settings[:port]}/clients")
    response = send_http_request(request)

    if !response.nil?
      if response.code == '200'
        json = JSON.parse(response.body)

        id_hash = json.inject({}) {
          |h, node| h[node['instance_id']] = \
          node['name'] if !node['instance_id'].nil?; h }

        @logger.debug("Got #{id_hash.keys.count} instance_ids out of #{json.count} Sensu clients.")
        return id_hash
      else
        @logger.fatal("Unexpected response from Sensu API (code: #{response.code}, message: #{response.message})")
      end
    end

    return nil
  end

  def delete_client(client)
    request = Net::HTTP::Delete.new URI("http://#{@settings[:host]}:#{@settings[:port]}/clients/#{client}")
    response = send_http_request(request)

    if !response.nil?
      log_delete_result(client, response.code)
    end
  end

  def log_delete_result(client, code)
    case code
    when '202'
        @logger.info("[202] Successfully deleted Sensu client: #{client}")
    when '404'
        @logger.error("[404] Unable to delete #{client}, doesn't exist!")
    when '500'
        @logger.error("[500] Miscellaneous error when deleting #{client}")
    else
        @logger.error("[#{response.code}] Completely unsure of what happened!")
    end
  end

end


class AwsApiConnector

  def initialize(region, aws_access_key_id, aws_secret_access_key, logger=nil)
    if logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
    else
      @logger = logger
    end

    Aws.config.update({
      :region      => region,
      :credentials => Aws::Credentials.new(aws_access_key_id, aws_secret_access_key),
    })
  end

  def get_ec2_instances_info
    @logger.debug('Retrieving list of EC2 instances from AWS API.')
    ec2 = Aws::EC2::Resource.new
    id_hash = ec2.instances().inject({}) \
	    { |m, i| m[i.id] = { 'state' => i.state['name'], 'tags' => i.tags }; m } rescue nil
    if !id_hash.nil?
      @logger.debug("Got #{id_hash.keys.count} AWS instances.")
    else
      @logger.fatal("Couldn't get the list of instances from AWS.")
    end
    id_hash
  end

end


class DeleteTerminatedEc2Clients

  def initialize(aws_region, log_level, noop=false, silent=false)
    @logger = Logger.new(STDOUT)
    @logger.level = log_level
    @noop = noop
    @silent = silent
    @aws_region = aws_region
  end

  def connect_aws()
    ac = _read_aws_creds_from_yaml(PATH_AWS_API_JSON)
    AwsApiConnector.new(
      @aws_region, ac['aws_access_key_id'], ac['aws_secret_access_key'], @logger)
  end

  def _read_aws_creds_from_yaml(creds_yaml)
    @logger.debug("Reading AWS API creds from #{creds_yaml}")
    YAML.load_file(creds_yaml)['default']
  end

  def main
    @sensu = SensuApiConnector.new(@logger) rescue nil
    if @sensu.nil?
      @logger.fatal('Failed to connect to Sesnu API.')
      return 1
    end

    @aws = connect_aws()

    _run
  end

  def _run()
    sensu_clients = @sensu.get_clients_with_instance_id
    return 1 if sensu_clients.nil?

    aws_instances = @aws.get_ec2_instances_info
    return 1 if aws_instances.nil?

    aws_instances = aws_instances.reject { |id, val| val['state'] == 'terminated' }
    @logger.debug("Found #{aws_instances.keys.count} non-terminated AWS instances.")

    diff = sensu_clients.keys - aws_instances.keys
    hosts_to_delete = []
    diff.each { |id| hosts_to_delete << sensu_clients[id] }

    @logger.info(diff.count > 0 ? "#{diff.count} Sensu clients to delete: " +
                hosts_to_delete.join(',') : "#{diff.count} Sensu clients to delete.")

    if (@silent and hosts_to_delete.count > 0)
      deleted_hosts = []

      open(PATH_LOG_FILE, "r") { |f|
        f.each_line { |line| deleted_hosts << /^(\S+)\s.*/.match(line)[1] }
      } rescue nil

      open(PATH_LOG_FILE, 'a') { |f|
        hosts_to_delete.each { |h| f.puts "#{h} #{Time.new.to_s}" if !deleted_hosts.include?(h) }
      } rescue nil
    end

    if !(sensu_clients.keys.count == diff.count and diff.count > 1)
      hosts_to_delete.each { |h| @sensu.delete_client(h) } if !@noop
      return 0
    elsif sensu_clients.keys.count == diff.count
      @logger.warn("Reject deletion of all Sensu clients.")
      return 1
    else
      # nothing to delete
      return 0
    end
  end

end # SensuCleanupAwsClients

if __FILE__ == $0

  opts = Trollop::options do
    opt :region, "AWS region to query", :type => String
    opt :verbose, "Run verbosely", :default => false
    opt :noop, "Do not delete sensu clients", :default => false
    opt :silent, "Only print hostnames that will be deleted from sensu", :default => false
  end

  Trollop::die :region, "must be set" unless !opts[:region].nil?

  log_level = opts[:verbose] ? Logger::DEBUG : Logger::INFO
  log_level = Logger::UNKNOWN if opts[:silent]

  job = DeleteTerminatedEc2Clients.new(opts.region, log_level, opts.noop, opts.silent)
  job.main()
end

#!/opt/puppet-omnibus/embedded/bin/ruby

# Delete all terminated or missing AWS clients from sensu
#
# 1. Get Sensu API creds from /etc/sensu/conf.d/api.json
# 2. Get Sensu clients that have a valid instance_id
# 3. Get AWS instance_id list
# 4. Find a diff between two lists
# 5. Delete all sensu clients listed in diff
#
# TODO: prevent from deletion all sensu clients when 
# instance_list.json is (partially?) empty

require 'trollop'
require 'logger'
require 'net/http'
require 'json'
require 'aws-sdk'
require 'aws-sdk-resources'

PATH_SENSU_API_JSON = '/etc/sensu/conf.d/api.json'
PATH_AWS_API_JSON = '/etc/sensu/cache_instance_list_creds.yaml'

class SensuApiConnector

  def initialize(host, port, user, pass, logger=nil)
    @sensu_host = host
    @sensu_port = port
    @sensu_user = user
    @sensu_pass = pass
    if logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
    else
      @logger = logger
    end

    @sensu_http = Net::HTTP.new(@sensu_host, @sensu_port)
    @sensu_http.open_timeout = 2
  end

  def send_http_request(request)
    request.basic_auth @sensu_user, @sensu_pass
    response = nil
    begin
      response = @sensu_http.request request # Net::HTTPResponse object
    rescue Net::OpenTimeout => e
      @logger.fatal("Can't connect to Sensu API (#{request.uri})")
    end
    response
  end

  def get_clients_with_instance_id
    @logger.debug('Retrieving clients list from Sensu API.')
    request = Net::HTTP::Get.new URI("http://#{@sensu_host}/clients")
    response = send_http_request(request)

    if !response.nil?
      if response.code == '200'
        json = JSON.parse(response.body)

        id_hash = json.inject({}) { 
          |h, node| h[node['instance_id']] = \
          node['name'] if !node['instance_id'].nil?; h }

        @logger.debug("Got #{id_hash.keys.count} (AWS) out of #{json.count} Sensu clients.")
        return id_hash
      else
        @logger.fatal("Unexpected response from Sensu API (code: #{response.code}, message: #{response.message})")
      end
    end

    return nil
  end

  def delete_client(client)
    request = Net::HTTP::Delete.new URI("http://#{@sensu_host}/clients/#{client}")
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
      'region'      => region,
      'credentials' => Aws::Credentials.new(aws_access_key_id, aws_secret_access_key),
    })
  end

  def get_ec2_instanses_info
    @logger.debug('Retrieving list of EC2 instances from AWS API.')
    ec2 = Aws::EC2::Resource.new
    id_hash = ec2.instances().inject({}) \
      { |m, i| m[i.id] = { 'state' => i.state['name'], 'tags' => i.tags }; m }
    @logger.debug("Got #{id_hash.keys.count} AWS instances.")
    id_hash
  end

end


class SensuCleanupAwsClients

  def initialize(aws_region, log_level, noop=false)
    @logger = Logger.new(STDOUT)
    @logger.level = log_level
    @noop = noop
  end

  def connect()
    sc = sensu_api_creds
    @sensu = SensuApiConnector.new(
      sc['host'], sc['port'], sc['user'], sc['pass'], @logger)

    ac = read_aws_creds_from_yaml(PATH_AWS_API_JSON)
    @aws = AwsApiConnector.new(
      aws_region, ac['aws_access_key_id'], ac['aws_secret_access_key'], @logger)
  end

  def read_aws_creds_from_yaml(creds_yaml)
    @logger.debug("Retrieving AWS API creds from #{creds_yaml}")
    YAML.load_file(creds_yaml)['default']
  end

  def sensu_api_creds
    @logger.debug("Retrieving Sensu connection info from #{PATH_SENSU_API_JSON}")
    f = File.open(PATH_SENSU_API_JSON)
    c = JSON.load(f)
    c = c['api']
    { 'host' => c['host'], 'port' => c['port'], 
      'user' => c['user'], 'pass' => c['password'] }
  end

  def main
    connect()

    sensu_clients = @sensu.get_clients_with_instance_id
    if sensu_clients.nil?
      return
    end

    aws_instances = @aws.get_ec2_instanses_info.reject { |id, val| val['state'] == 'terminated' }
    @logger.debug("Found #{aws_instances.keys.count} non-terminated AWS instances.")

    diff = sensu_clients.keys - aws_instances.keys
    @logger.info("#{diff.count} Sunsu clients to delete.")

    if !(sensu_clients.keys.count == diff.count and diff.count > 1)
      diff.each { |h| sensu_delete_client(sensu_clients[h]) } if !@noop
    else
      @logger.warn("Rejecting to delete all Sensu clients.")
    end
  end

end # SensuCleanupAwsClients

if __FILE__ == $0

  opts = Trollop::options do
    opt :verbose, "Run verbosely", :default => false
    opt :noop, "Do not delete sensu clients", :default => false
    opt :region, "AWS region to query", :type => String
  end

  Trollop::die :region, "must be set" unless !opts[:region].nil?

  log_level = opts[:verbose] ? Logger::DEBUG : Logger::INFO

  job = SensuCleanupAwsClients.new(opts.region, log_level, opts.noop)
  job.main()
end


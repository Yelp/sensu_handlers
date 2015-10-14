#!/opt/puppet-omnibus/embedded/bin/ruby

# Delete all terminated or missing AWS clients from sensu
#
# 1. Get Sensu API creds from /etc/sensu/conf.d/api.json
# 2. Get Sensu clients that have a valid instance_id
# 3. Get AWS instance_id list from /var/cache/instance_list.json
# 4. Find a diff between two lists
# 5. Delete all sensu clients listed in diff
#
# TODO: prevent from deletion all sensu clients when 
# instance_list.json is (partially?) empty

require 'logger'
require 'net/http'
require 'json'

PATH_SENSU_API_JSON = '/etc/sensu/conf.d/api.json'
PATH_AWS_INSTANCE_LIST_JSON = '/var/cache/instance_list.json'

class SensuCleanupAwsClients

  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @sensu_creds = sensu_api_creds
  end

  def load_instances_cache
    @logger.debug("Loading AWS data from cache (#{PATH_AWS_INSTANCE_LIST_JSON})")
    f = File.open(PATH_AWS_INSTANCE_LIST_JSON)
    instances = JSON.load(f)
    bail if instances.nil?
    id_hash = Hash.new
    instances.each { |r| id_hash[r['id']] = { 'state' => r['state'], 'tags' => r['tags']} }
    @logger.debug("Loaded #{id_hash.keys.count} instances.")
    id_hash
  end

  def sensu_api_creds
    #@logger.debug("Loading Sensu API creds from #{PATH_SENSU_API_JSON}")
    f = File.open(PATH_SENSU_API_JSON)
    c = JSON.load(f)
    c = c['api']
    { 'host' => c['host'], 'port' => c['port'], 
      'user' => c['user'], 'pass' => c['password'] }
  end

  def send_http_request(request)
    response = nil
    Net::HTTP.start(@sensu_creds['host'], @sensu_creds['port']) do |http|
      request.basic_auth @sensu_creds['user'], @sensu_creds['pass']
      response = http.request request # Net::HTTPResponse object
    end
    response
  end

  def sensu_get_clients_with_instance_id
    @logger.debug('Retrieving clients list from Sensu API.')
    request = Net::HTTP::Get.new URI("http://#{@sensu_creds[:host]}/clients")
    response = send_http_request(request)

    json = JSON.parse(response.body)
    id_hash = Hash.new
    json.each do |c| 
      if !c['instance_id'].nil?
        id_hash[c['instance_id']] = c['name']
      end
    end

    @logger.debug("Got #{id_hash.keys.count} (AWS) out of #{json.count} clients.")
    id_hash
  end

  def sensu_delete_client(client)
    request = Net::HTTP::Get.new URI("http://#{@sensu_creds[:host]}/clients/#{client}") # TODO switch from Get to Delete
    response = send_http_request(request)

    case response.code
    when '202'
        @logger.info("EC2 Node - [202] Successfully deleted Sensu client: #{client}")
    when '404'
        @logger.error("EC2 Node - [404] Unable to delete #{client}, doesn't exist!")
    when '500'
        @logger.error("EC2 Node - [500] Miscellaneous error when deleting #{client}")
    else
        @logger.error("EC2 Node - [#{response.code}] Completely unsure of what happened!")
    end
  end

  def main
    sensu_clients = sensu_get_clients_with_instance_id
    aws_instances = load_instances_cache
  
    diff = sensu_clients.keys - aws_instances.keys
    @logger.info("#{diff.count} Sunsu clients to delete.")
    diff.each { |h| sensu_delete_client(sensu_clients[h]) }
  end

end # SensuCleanupAwsClients

job = SensuCleanupAwsClients.new
job.main


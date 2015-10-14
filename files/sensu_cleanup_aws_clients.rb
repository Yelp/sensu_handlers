#!/opt/puppet-omnibus/embedded/bin/ruby

require 'net/http'
require 'json'

def load_instances_cache
  f = File.open('/var/cache/instance_list.json')
  instances = JSON.load(f)
  bail if instances.nil?
  id_hash = Hash.new
  instances.each { |r| id_hash[r['id']] = { 'state' => r['state'], 'tags' => r['tags']} }
  id_hash
end

def sensu_api_creds
  f = File.open('/etc/sensu/conf.d/api.json')
  c = JSON.load(f)
  c = c['api']
  { 'host' => c['host'], 'port' => c['port'], 
    'user' => c['user'], 'pass' => c['password'] }
end

def sensu_get_clients_with_instance_id(creds)
  uri = URI("http://#{creds[:host]}/clients")
  response = nil
  Net::HTTP.start(creds['host'], creds['port']) do |http|
    request = Net::HTTP::Get.new uri
    request.basic_auth creds['user'], creds['pass']
    response = http.request request # Net::HTTPResponse object
  end

  json = JSON.parse(response.body)
  id_hash = Hash.new
  json.each do |c| 
    if !c['instance_id'].nil?
      id_hash[c['instance_id']] = c['name']
    end
  end
  id_hash
end

def sensu_delete_client(creds, client)
  uri = URI("http://#{creds[:host]}/clients/#{client}")
  response = nil
  Net::HTTP.start(creds['host'], creds['port']) do |http|
    request = Net::HTTP::Get.new uri # TODO switch from Get to Delete
    request.basic_auth creds['user'], creds['pass']
    response = http.request request # Net::HTTPResponse object
  end
  puts response.code, response.body
end

def main
  sensu_creds = sensu_api_creds

  sensu_clients = sensu_get_clients_with_instance_id(sensu_creds)
  awsinstances = load_instances_cache

  diff = sensu_clients.keys - aws_instances.keys
  diff.each { |h| sensu_delete_client(sensu_creds, sensu_clients[h]) }
end

main


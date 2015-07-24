#!/usr/bin/env ruby
#
# This handler removes a Sensu client if it has been terminated in EC2.
#
# NOTE: The implementation for correlating Sensu clients to EC2 instances may
# need to be modified to fit your organization. The current implementation
# assumes that Sensu clients' names are the same as their instance IDs in EC2.
# If this is not the case, you can either sub-class this handler and override
# `ec2_node_exists?` in your own organization-specific handler, or modify this
# handler to suit your needs.
#
# Requires the following Rubygems (`gem install $GEM`):
#   - sensu-plugin
#   - fog
#
# Requires a Sensu configuration snippet:
#   {
#     "aws": {
#       "access_key": "adsafdafda",
#       "secret_key": "qwuieohajladsafhj23nm",
#       "region": "us-east-1c"
#     }
#   }
#
# Or you can set the following environment variables:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - EC2_REGION
#
#
# To use, you can set it as the keepalive handler for a client:
#   {
#     "client": {
#       "name": "i-424242",
#       "address": "127.0.0.1",
#       "keepalive": {
#         "handler": "ec2_node"
#       },
#       "subscriptions": ["all"]
#     }
#   }
#
# You can also use this handler with a filter:
#   {
#     "filters": {
#       "ghost_nodes": {
#         "attributes": {
#           "check": {
#             "name": "keepalive",
#             "status": 2
#           },
#           "occurences": "eval: value > 2"
#         }
#       }
#     },
#     "handlers": {
#       "ec2_node": {
#         "type": "pipe",
#         "command": "/etc/sensu/handlers/ec2_node.rb",
#         "severities": ["warning","critical"],
#         "filter": "ghost_nodes"
#       }
#     }
#   }
#
# Copyleft 2013 Yet Another Clever Name
#
# Based off of the `chef_node` handler by Heavy Water Operations, LLC
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details

require 'timeout'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'

class Ec2Node < Sensu::Handler

  def filter; end

  def handle
    unless ec2_node_exists?(@event['client']['instance_id'])
      delete_sensu_client!
    else
      puts "EC2 Node - #{@event['client']['name']} appears to exist in EC2"
    end
  end

  def delete_sensu_client!
    response = api_request(:DELETE, '/clients/' + @event['client']['name']).code
    deletion_status(response)
  end

  def blacklist_name_array
    return [] unless settings['aws_prune']
    settings['aws_prune']['blacklist_name_array'] || []
  end

  def load_instances_cache
    f = File.open('/var/cache/instance_list.json')
    instances = JSON.load(f)
    bail if instances.nil? 
    instances
  end

  def ec2_node_exists?(instance_id)
    running_instances = load_instances_cache
    instance_ids = running_instances.reject { |s| instance_id != s['id'] || s['state'] == 'terminated' || s['state'] == 'shutting-down' }.collect { |s| Hash[ 'id', s['id'], 'tags', s['tags'] ]}
    return false unless instance_ids.size > 0
    instance = instance_ids[0]
    # Yelp specific: pretend that the node does not exist if we are in our blacklist
    instance_name = instance['tags']['Name'].to_s
    return false if blacklist_name_array.include?(instance_name)
    return true if instance_id == instance['id']
  end

  def deletion_status(code)
    node = @event['client']['name']
    case code
    when '202'
      puts "EC2 Node - [202] Successfully deleted Sensu client: #{node}"
    when '404'
      puts "EC2 Node - [404] Unable to delete #{node}, doesn't exist!"
    when '500'
      puts "EC2 Node - [500] Miscellaneous error when deleting #{node}"
    else
      puts "EC2 Node - [#{code}] Completely unsure of what happened!"
    end
  end

end


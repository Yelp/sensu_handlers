# == Class: sensu_handlers
#
# Sensu handler installation and configuration.
#
# == Parameters
#
# [*teams*]
#  A hash configuring the different desired configuration for the default
#  handler behavior given a particular team. See the main README.md for
#  examples. This parameter is required.
#
# [*package_ensure*]
#  Currently unused.
#
# [*default_handler_array*]
#  An array of the handlers you want base handler to spawn.
#  This array ends up matching the class names that get included. For
#  example:
#
#  default_handler_array =>  [ 'nodebot', 'pagerduty' ]
#  Will include sensu_handlers::nodebot and sensu_handlers::pagerduty
#
# [*jira_username*]
# [*jira_password*]
# [*jira_site*]
#  If you are using the JIRA handler, it needs basic auth to work.
#  Fill in the credentials and url to your local JIRA instance.
#
# [*use_embeded_ruby*]
#  use provider => sensu_gem for any gem packages
#
# [*api_client_config*]
# Out of the box Sensu::Handler connects to sensu-api instance described in
# /etc/sensu/conf.d/api.json which is a local instance. This param sets
# alternative endpoint - for example, by pointing to haproxy. Expects hash
# with at least 'host' and 'port' keys.
#
# [*use_num_occurrences_filter*]
# Boolean toggle whether to use num_occurrences_filter (this filter is
# implemented as a sensu extension, it runs witin sensu-process). If not sure,
# don't use it and set this to false.
#
class sensu_handlers(
  $teams,
  $package_ensure             = 'latest',
  $default_handler_array      = [ 'nodebot', 'pagerduty', 'mailer', 'jira' ],
  $jira_username              = 'sensu',
  $jira_password              = 'sensu',
  $jira_site                  = "jira.${::domain}",
  $mailer_runbook             = 'http://y/unkown',
  $mailer_server              = 'localhost',
  $mailer_tip                 = '',
  $opsgenie_runbook           = 'http://y/rb-pagerduty',
  $opsgenie_tip               = 'is Ops genie up?',
  $pagerduty_runbook          = 'http://y/rb-pagerduty',
  $pagerduty_tip              = 'is PD up? https://events.pagerduty.com?',
  $team                       = 'operations',
  $datacenter                 = $::datacenter,
  $dashboard_link             = "https://sensu.${::domain}",
  $use_embedded_ruby          = false,
  $api_client_config          = {},
  $use_num_occurrences_filter = false,
) {

  validate_hash($teams, $api_client_config)

  $gem_provider = $use_embedded_ruby ? {
    true    => 'sensu_gem',
    default => 'gem'
  }

  if !empty($api_client_config) {
    file { '/etc/sensu/conf.d/api_client.json':
      owner   => 'sensu',
      group   => 'sensu',
      mode    => '0444',
      content => inline_template('<%= JSON.pretty_generate("api_client" => @api_client_config) %>'),
      before  => File['/etc/sensu/handlers/base.rb'],
    }
  }

  if $use_num_occurrences_filter {
    $num_occurrences_filter = [ 'num_occurrences_filter' ]
    $num_occurrences_filter_for_pagerduty = [ 'num_occurrences_filter_for_pagerduty' ]
    file { '/etc/sensu/extensions/num_occurrences_filter.rb':
      owner  => 'sensu',
      group  => 'sensu',
      mode   => '0444',
      source => 'puppet:///modules/sensu_handlers/num_occurrences_filter.rb',
      notify => Service['sensu-server'],
    }
  }
  else {
    $num_occurrences_filter = []
    $num_occurrences_filter_for_pagerduty = []
  }

  file { '/etc/sensu/handlers/base.rb':
    source => 'puppet:///modules/sensu_handlers/base.rb',
    mode   => '0644',
    owner  => root,
    group  => root;
  } ->
  sensu::handler { 'default':
    type      => 'set',
    command   => true,
    handlers  => $default_handler_array,
    config    => {
      dashboard_link => $dashboard_link,
      datacenter     => $datacenter,
    }
  }

  # We compose an array of classes depending on the handlers requested
  $handler_classes = prefix($default_handler_array, 'sensu_handlers::')
  # This ends up being something like [ 'sensu_handlers::nodebot', 'sensu_handlers::pagerduty' ]
  include $handler_classes
}

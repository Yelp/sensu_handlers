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
class sensu_handlers(
  $teams,
  $package_ensure        = 'latest',
  $default_handler_array = [ 'nodebot', 'pagerduty', 'opsgenie', 'mailer' ],
  $jira_username         = 'sensu',
  $jira_password         = 'sensu',
  $jira_site             = "jira.${::domain}",
  $include_graphite      = true,
  $include_aws_prune     = true,
) {

  validate_hash($teams)
  validate_bool($include_graphite, $include_aws_prune)

  ensure_packages(['sensu-community-plugins'])

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
  }

  # We compose an array of classes depending on the handlers requested
  $handler_classes = prefix($default_handler_array, 'sensu_handlers::')
  # This ends up being something like [ 'sensu_handlers::nodebot', 'sensu_handlers::pagerduty' ]
  include $handler_classes

  if $include_graphite {
    include sensu_handlers::graphite
  }

  if $include_aws_prune {
    include sensu_handlers::aws_prune
  }
}


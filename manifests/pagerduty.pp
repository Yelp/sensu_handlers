# == Class: sensu_handlers::pagerduty
#
# Sensu handler for communicating with Pagerduty
#
class sensu_handlers::pagerduty (
  $dependencies = {
    'redphone' => { provider => $gem_provider },
  }
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensu::Handler['pagerduty'] }
  )

  sensu::filter { 'page_filter':
    attributes => { 'check' => { 'page' => true } },
  } ->
  sensu::handler { 'pagerduty':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/pagerduty.rb',
    config  => {
      teams => $teams,
    },
    filters => flatten([
      'page_filter',
      $sensu_handlers::num_occurrences_filter,
    ]),
  } ->
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_pagerduty':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H events.pagerduty.com -e 404',
    runbook  => $sensu_handlers::pagerduty_runbook,
    tip      => $sensu_handlers::pagerduty_tip,
  }

}

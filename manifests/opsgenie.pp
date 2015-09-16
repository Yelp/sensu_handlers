# == Class: sensu_handlers::opsgenie
#
# Sensu handler for openening and closing OpsGenie incidents.
#
class sensu_handlers::opsgenie inherits sensu_handlers {

  sensu::handler { 'opsgenie':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/opsgenie.rb',
    config  => {
      teams => $teams,
    }
  }
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_opsgenie':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H api.opsgenie.com',
    runbook  => 'http://y/rb-pagerduty',
    tip      => 'is Ops genie up?',
  }

}

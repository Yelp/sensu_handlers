# == Class: sensu_handlers::pagerduty
#
# Sensu handler for communicating with Pagerduty
#
class sensu_handlers::pagerduty inherits sensu_handlers {

  ensure_packages(['rubygem-redphone'])
  sensu::handler { 'pagerduty':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/pagerduty.rb',
    config  => {
      teams => $teams,
    },
    require => [ Package['rubygem-redphone'] ],
  }
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_pagerduty':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H events.pagerduty.com -e 404',
    runbook  => 'http://y/rb-pagerduty',
    tip      => 'is PD up? https://events.pagerduty.com?',
  }

}

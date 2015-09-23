# == Class: sensu_handlers::mailer
#
# Sensu handler to send emails.
#
class sensu_handlers::mailer (
  $dependencies = {
    'nagios-plugins-basic' => {},
    'mail'                 => { 'provider' => 'gem' }
  }
) inherits sensu_handlers {

  sensu_handlers::deps {'mailer': dependencies => $dependencies }

  sensu::handler { 'mailer':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/mailer.rb',
    config  => {
      teams => $teams,
    }
  }

  monitoring_check { 'check_smtp_for_sensu_handler':
    check_every   => '5m',
    alert_after   => '10m',
    realert_every => '10',
    page          => false,
    team          => 'operations',
    command       => '/usr/lib/nagios/plugins/check_smtp -H localhost',
    runbook       => 'y/?',
  }

}

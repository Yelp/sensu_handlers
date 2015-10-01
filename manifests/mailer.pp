# == Class: sensu_handlers::mailer
#
# Sensu handler to send emails.
#
class sensu_handlers::mailer (
  $dependencies = {
    'nagios-plugins-basic' => {
      ensure => 'installed',
    },
    'mail' => {
      provider => $gem_provider,
      ensure   => '2.5.4',
    }
  }
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensu::Handler['mailer'] }
  )

  sensu::handler { 'mailer':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/mailer.rb',
    config  => {
      teams => $teams,
    }
  } ->

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

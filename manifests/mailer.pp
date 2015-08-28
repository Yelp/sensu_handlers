# == Class: sensu_handlers::mailer
#
# Sensu handler to send emails.
#
class sensu_handlers::mailer inherits sensu_handlers {

  ensure_packages(['nagios-plugins-basic'])

  case $::osfamily {
    'Debian': {
      $mail_package = 'ruby-mail'
      $mail_version = '2.5.4-2'
    }
    default:  {
      $mail_package = 'rubygem-mail'
      $mail_version = '2.5.4'
    }
  }

  package { $mail_package:
    ensure => $mail_version,
  } ->
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
    require       => [ Package['nagios-plugins-basic'] ],
  }

}

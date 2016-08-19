# == Class: sensu_handlers::mailer
#
# Sensu handler to send emails.
#
# [*mail_from*]
#  required.  the "From: " address for emails sent from this handler
#
class sensu_handlers::mailer (
  $mail_from,
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
    filters => flatten([
      $sensu_handlers::num_occurrences_filter,
    ]),
    config  => {
      teams     => $teams,
      mail_from => $mail_from
    }
  } ->

  monitoring_check { 'check_smtp_for_sensu_handler':
    check_every   => '5m',
    alert_after   => '10m',
    realert_every => '10',
    page          => false,
    team          => $sensu_handlers::team,
    command       => "/usr/lib/nagios/plugins/check_smtp -H ${sensu_handlers::mailer_server},",
    runbook       => $sensu_handlers::mailer_runbook,
    tip           => $sensu_handlers::mailer_tip,
  }

}

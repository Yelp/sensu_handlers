# == Class: sensu_handlers::nodebot
#
# Sensu handler for sending IRC via nodebot
# https://github.com/thwarted/nodebot
#
class sensu_handlers::nodebot inherits sensu_handlers {

 sensu::handler { 'nodebot':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/nodebot.rb',
    config  => {
      teams => $teams,
    },
    require => Package['sensu-community-plugins'];
  }
  monitoring_check { 'irc.local_tcp6697':
    check_every => '10m',
    command  => '/usr/lib/nagios/plugins/check_tcp -H irc.local.yelpcorp.com -p 6697',
    runbook  => 'http://y/rb-irc',
    tip      => "Is irc.local setup for this habitat? (${::habitat})",
  }

}

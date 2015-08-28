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
    }
  }

}

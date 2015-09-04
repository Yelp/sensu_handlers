# == Class: sensu_handlers::hipchat
#
# Sensu handler for sending to hipchat using hipchat gem
class sensu_handlers::hipchat inherits sensu_handlers {

 sensu::handler { 'hipchat':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/hipchat.rb',
    config  => {
      teams => $teams,
    }
  }

}

# == Class: sensu_handlers::hipchat
#
# Sensu handler for sending to hipchat using hipchat gem
#
# == Parameters
#
# [*api_key*]
#
#  hipchat api key
class sensu_handlers::hipchat (
  $api_key,
  $default_room = false,
  $dependencies = {
    'hipchat' => {'provider' => $gem_provider }
  }
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensu::Handler['mailer'] }
  )

  sensu::handler { 'hipchat':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/hipchat.rb',
    config  => {
      api_key      => $api_key,
      teams        => $teams,
      default_room => $default_room,
    }
  }

}

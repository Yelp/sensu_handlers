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
  $use_default_pager = false, # backwards compatibility.
  $dependencies = {
    'hipchat' => {'provider' => $gem_provider }
  }
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensu::Handler['hipchat'] }
  )

  sensu::handler { 'hipchat':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/hipchat.rb',
    config  => {
      api_key           => $api_key,
      teams             => $teams,
      use_default_pager => $use_default_pager,
    }
  }

}

# == Class: sensu_handlers::sensu_slo
#
# Sensu handler to calculate the age of a check and send it to statsite.
#
class sensu_handlers::sensu_slo (
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensu::Handler['sensu_slo'] }
  )

  sensu::handler { 'sensu_slo':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/sensu_slo.rb',
    config  => {
    }
  }

}

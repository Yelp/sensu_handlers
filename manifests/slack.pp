# == Class: sensu_handlers::slack
#
# Sensu handler for sending to slack
#
class sensu_handlers::slack (
  $webhook_url
) inherits sensu_handlers {

  sensu::handler { 'slack':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/slack.rb',
    filters => flatten([
      $sensu_handlers::num_occurrences_filter,
    ]),
    config  => {
      teams       => $teams,
      webhook_url => $webhook_url,
    }
  }

}

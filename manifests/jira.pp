# == Class: sensu_handlers::jira
#
# Sensu handler to open and close Jira tickets for you.
#
class sensu_handlers::jira (
  $dependencies = {
    'jira-ruby' => {
      ensure   => '0.1.9',
      provider => $gem_provider,
    }
  }
) inherits sensu_handlers {

  create_resources(
    'package',
    $dependencies,
    { before => Sensu::Handler['jira'] }
  )

  sensu::filter { 'ticket_filter':
    attributes => { 'check' => { 'ticket' => true } },
  } ->
  sensu::handler { 'jira':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/jira.rb',
    config  => {
      teams        => $teams,
      username     => $jira_username,
      password     => $jira_password,
      site         => $jira_site,
      priority_map => $jira_priority_map,
    },
    filters => flatten([
      'ticket_filter',
      $sensu_handlers::num_occurrences_filter,
    ]),
  }
}

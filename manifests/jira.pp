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
      teams    => $teams,
      username => $jira_username,
      password => $jira_password,
      site     => $jira_site,
    },
    filters => [ 'ticket_filter' ],
  }
  if $::lsbdistcodename == 'Lucid' {
    # So sorry for the httprb monkeypatch. It is Debian bug 564168 that took
    # me forever to track down. Maybe someday we'll use a newer ruby.
    # Afterall, who supports versions that are EOL?
    # https://www.ruby-lang.org/en/news/2013/06/30/we-retire-1-8-7/
    # What are they going to deprecate next? ifconfig?
    file_line { 'fix_httprb_564168':
      match => '      @socket.close unless.*',
      line  => '      @socket.close unless @socket.nil? || @socket.closed?',
      path  => '/usr/lib/ruby/1.8/net/http.rb',
    }
  }

}

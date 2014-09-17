# == Class: sensu_handlers
#
# Sensu handler installation and configuration.
#
# == Parameters
#
# [*teams*]
#  A hash configuring the different desired configuration for the default
#  handler behavior given a particular team. See the main README.md for 
#  examples. This parameter is required.
#  
class sensu_handlers(
  $package_ensure = 'latest',
  $default_handler_array  = [ 'nodebot', 'pagerduty', 'opsgenie', 'mailer' ],
  $jira_username,
  $jira_password,
  $jira_site,
  $teams,
) {

  validate_hash($teams)

  sensu::handler { 'default':
    type      => 'set',
    command   => true,
    handlers  => $default_handler_array,
  }

  # Pagerduty. Probably needs to be splitout
  ensure_packages(['rubygem-redphone'])


  file { '/etc/sensu/handlers/base.rb':
    source => 'puppet:///modules/sensu_handlers/base.rb',
    mode   => '0644',
    owner  => root,
    group  => root;
  }

  # EMAIL
  package { 'rubygem-mail':
    ensure => '2.5.4',
  } ->
  sensu::handler { 'mailer':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/mailer.rb',
    config  => {
      teams => $teams,
    },
    require => [ Package['nagios-plugins-basic'] ],
  }
  monitoring_check { 'check_smtp_for_sensu_handler':
    check_every   => '5m',
    alert_after   => '10m',
    realert_every => '10',
    page          => false,
    team          => 'operations',
    command       => '/usr/lib/nagios/plugins/check_smtp -H localhost',
    runbook       => 'y/?',
  }

  # Pagerduty
  sensu::handler { 'pagerduty':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/pagerduty.rb',
    config  => {
      teams => $teams,
    },
    require => [ Package['sensu-community-plugins'], Package['rubygem-redphone'] ],
  }
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_pagerduty':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H events.pagerduty.com -e 404',
    runbook  => 'http://y/rb-pagerduty',
    tip      => 'is PD up? https://events.pagerduty.com?',
  }

  # OPS GENIE
  sensu::handler { 'opsgenie':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/opsgenie.rb',
    config  => {
      teams => $teams,
    },
    require => [ Package['sensu-community-plugins'] ],
  }
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_opsgenie':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H api.opsgenie.com',
    runbook  => 'http://y/rb-pagerduty',
    tip      => 'is Ops genie up?',
  }

  # IRC
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

  # JIRA
  package { 'rubygem-jira-ruby': ensure => '0.1.9' } ->
  sensu::handler { 'jira':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/jira.rb',
    config  => {
      teams    => $teams,
      username => $jira_username,
      password => $jira_password,
      site     => $jira_site,
    },
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

  # Graphite
  file { '/etc/sensu/conf.d/mutators':
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0755';
  }
  $graphite_data = {
    mutators => {
      graphite => {
        command => 'RUBYOPT=rubygems /usr/share/sensu-community-plugins/mutators/graphite.rb --reverse'
      }
    }
  }
  file { '/etc/sensu/conf.d/mutators/graphite.json':
      owner   => root,
      group   => root,
      mode    => '0444',
      content => inline_template('<%= require "json"; JSON.generate @graphite_data %>'),
      require => Package['sensu-community-plugins'],
  }

  if hiera(ready_for_new_sensu, false) == true {
    sensu::handler { 'graphite':
      type     => 'transport',
      config => {
        'pipe' => {
          type    => 'topic',
          name    => 'metrics',
          durable => true
        }
      },
      mutator  => 'graphite'
    }
  } else { 
    sensu::handler { 'graphite':
      type     => 'amqp',
      exchange => {
        type    => 'topic',
        name    => 'metrics',
        durable => true
      },
      mutator  => 'graphite'
    }
  }

  # Only EC2 Sensu servers need to worry about querying the AWS api to know if 
  # They need to prune or not
  if str2bool($::is_ec2) == true {
    ensure_packages(['rubygem-fog', 'rubygem-unf'])
    # We currently use $::habitat::datacenter for the AWS region.
    # This may change someday.
    $region = $::habitat::datacenter
    $access_key = hiera('sensu::aws_key')
    $secret_key = hiera('sensu::aws_secret')
    $aws_config_hash =  {
      access_key => $access_key,
      secret_key => $secret_key,
      region     => $region,
      blacklist_name_array => [ 'bake_soa_ami', 'Packer Builder' ]
    }
    sensu::handler { 'aws_prune':
      type    => 'pipe',
      source  => 'puppet:///modules/sensu_handlers/aws_prune.rb',
      config  => $aws_config_hash,
      require => [ Package['rubygem-fog'], Package['rubygem-sensu-plugin'], Package['rubygem-unf'] ],
    }
    file { '/etc/sensu/plugins/cache_instance_list.rb':
      owner   => 'root',
      group   => 'root',
      mode    => '0500',
      source  => 'puppet:///modules/sensu_handlers/cache_instance_list.rb',
      require => [ Package['rubygem-fog'], Package['rubygem-sensu-plugin'], Package['rubygem-unf'] ],
    } -> 
    cron::d { 'cache_instance_list':
      minute  => '*',
      user    => 'root',
      command => "/etc/sensu/plugins/cache_instance_list.rb -a ${access_key} -r ${region} -k ${secret_key}",
    } ->
    monitoring_check { 'cache_instance_list-staleness':
     check_every => '10m',
     alert_after => '1h',
     team        => 'operations',
     runbook     => 'y/rb-unknown',
     tip         => 'talk to kwa',
     command     => "/usr/lib/nagios/plugins/check_file_age /var/cache/instance_list.json -w 1800 -c 3600",
     page        => false,
   }
 }

}

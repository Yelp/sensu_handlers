# == Class: sensu_handlers::graphite
#
# Sensu handler for installing the graphite metric transport
#  
class sensu_handlers::graphite inherits sensu_handlers {

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

  sensu::handler { 'graphite':
    type     => 'transport',
    pipe => {
      'type'  => 'topic',
      name    => 'metrics',
      durable => true
    },
    mutator  => 'graphite'
  }

}

# == Class: sensu_handlers::aws_prune
#
# Sensu handler for removing clients from sensu if they are not in the AWS
# API.
#
class sensu_handlers::aws_prune (
  $manage_deps = $sensu_handlers::manage_deps
) inherits sensu_handlers {

  # Only EC2 Sensu servers need to worry about querying the AWS api to know if 
  # They need to prune or not
  if str2bool($::is_ec2) == true {

    $access_key = hiera('sensu::aws_key')
    $secret_key = hiera('sensu::aws_secret')

    validate_string($access_key, $secret_key, $region)

    if $manage_deps {
      package {['fog', 'unf']:
        provider => $gem_provider,
        before   => [
          Sensu::Handler['aws_prune'],
          # hmm, TODO: dep on all files,  dep on anchor, no deps?
          File['/etc/sensu/plugins/cache_instance_list.rb']
        ]
      }
    }

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
    }
    file { '/etc/sensu/plugins/cache_instance_list.rb':
      owner   => 'root',
      group   => 'root',
      mode    => '0500',
      source  => 'puppet:///modules/sensu_handlers/cache_instance_list.rb',
    } ->
    file { '/etc/sensu/cache_instance_list_creds.yaml':
      owner   => 'root',
      group   => 'root',
      mode    => '0400',
      content => template('sensu_handlers/cache_instance_list_creds.erb'),
    } ->
    cron::d { 'cache_instance_list':
      minute  => '*',
      user    => 'root',
      command => "/opt/puppet-omnibus/embedded/bin/ruby /etc/sensu/plugins/cache_instance_list.rb -r ${region} -f /etc/sensu/cache_instance_list_creds.yaml",
    } ->
    monitoring_check { 'cache_instance_list-staleness':
     check_every => '10m',
     alert_after => '1h',
     team        => 'operations',
     runbook     => 'y/rb-unknown',
     tip         => 'talk to kwa',
     command     => "/usr/lib/nagios/plugins/check_file_age /var/cache/instance_list.json -w 1800 -c 3600",
     page        => false,
     ticket      => true,
   }
 }

}

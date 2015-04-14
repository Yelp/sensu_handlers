# == Class: sensu_handlers::aws_prune
#
# Sensu handler for removing clients from sensu if they are not in the AWS
# API.
#
class sensu_handlers::aws_prune inherits sensu_handlers {

  # Only EC2 Sensu servers need to worry about querying the AWS api to know if 
  # They need to prune or not
  if str2bool($::is_ec2) == true {

    $access_key = hiera('sensu::aws_key')
    $secret_key = hiera('sensu::aws_secret')

    validate_string($access_key, $secret_key, $region)

    ensure_packages(['rubygem-fog', 'rubygem-unf'])
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
    file { '/etc/sensu/cache_instance_list_creds.yaml':
      owner   => 'root',
      group   => 'root',
      mode    => '0400',
      content => template('sensu_handlers/cache_instance_list_creds.erb'),
    } ->
    cron::d { 'cache_instance_list':
      minute  => '*',
      user    => 'root',
      command => "/etc/sensu/plugins/cache_instance_list.rb -r ${region} -f /etc/sensu/cache_instance_list_creds.yaml",
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

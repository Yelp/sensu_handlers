# == Class: sensu_handlers::delete_terminated
#
# == Parameters
#
# [*region*]
#  The aws region so the aws_prune handler knows wich API endpoint to query
#
class sensu_handlers::delete_terminated_ec2 (
  $region = undef,
) {

  validate_string($region)

  # Only EC2 Sensu servers need to worry about querying the AWS api to know if
  # They need to prune or not
  if str2bool($::is_ec2) == true {

    $access_key = hiera('sensu::aws_key')
    $secret_key = hiera('sensu::aws_secret')

    file { '/etc/sensu/delete_terminated_ec2_creds.yaml':
      owner   => 'sensu',
      group   => 'sensu',
      mode    => '0400',
      content => template('sensu_handlers/delete_terminated_ec2_creds.erb'),
    } ->

    file { '/etc/sensu/plugins/delete_terminated_ec2_clients.rb':
      owner  => 'sensu',
      group  => 'sensu',
      mode   => '0555',
      source => 'puppet:///modules/sensu_handlers/delete_terminated_ec2_clients.rb',
    } ->

    cron::d { 'sensu_delete_terminated_ec2s':
      minute        => '*',
      user          => 'sensu',
      command       => "/etc/sensu/plugins/delete_terminated_ec2_clients.rb -s -r ${region} 2>&1",
      comment       => 'Delete terminated ec2 clients from sensu',
      log_to_syslog => false,
    }

  }
}

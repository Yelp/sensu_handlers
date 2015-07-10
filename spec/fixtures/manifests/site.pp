Package {
  provider => 'apt'
}
include apt
include sensu

package { 'rubygem-sensu-plugin': }

define cron::d (
  $minute,
  $command,
  $user,
  $second='0',
  $hour='*',
  $dom='*',
  $month='*',
  $dow='*',
  $mailto='""',
  $log_to_syslog=true,
  $staleness_threshold=undef,
  $staleness_check_params=undef,
  $annotation='',
  $lock=false,
  $normalize_path=hiera('cron::d::normalize_path', false),
  $comment='',
) { }

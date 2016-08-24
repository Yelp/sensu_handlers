Package {
  provider => 'apt'
}
include apt
include sensu

package { 'rubygem-sensu-plugin': }

source 'https://rubygems.org'

# Puppet parts
gem "rake"
gem "puppet", ENV['PUPPET_VERSION'] || '~> 3.7.0'
gem "puppetlabs_spec_helper"
# TODO: Bump to 1.0.2 when it is out.
gem "rspec-puppet",
  :git => 'https://github.com/bobtfish/rspec-puppet.git',
  :ref => '06aa6c675baafa538b4d06107fc239cd025159fd'
gem 'hiera-puppet-helper',
  :git => 'https://github.com/bobtfish/hiera-puppet-helper.git',
  :ref => '5ed989a130bc62cc6bdb923596586284f0bd73df'

# Sensu Handler Parts
gem 'sensu-plugin'
gem 'mail', '~> 2.5.4'

require 'spec_helper'
require 'hiera-puppet-helper'

describe 'sensu_handlers::aws_prune', :type => :class do

  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
    :is_ec2 => true,
  }}

  let(:hiera_data) {{
    :'sensu_handlers::teams' => { 'operations' => {} },
    :'sensu_handlers::default_handler_array' => [],
    :'sensu::aws_key' => 'mock_sensu_aws_key',
    :'sensu::aws_secret'  => 'mock_sensu_aws_secret',
  }}

  context 'should compile' do
    it { should compile }
    it {
      should contain_file('/etc/sensu/plugins/cache_instance_list.rb')
      should contain_file('/etc/sensu/cache_instance_list_creds.yaml') \
        .with_mode('0400') \
        .with_content(/aws_access_key_id: mock_sensu_aws_key/) \
        .with_content(/aws_secret_access_key: mock_sensu_aws_secret/)
    }
  end

end

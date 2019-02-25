require 'spec_helper'

describe 'sensu_handlers::jira', :type => :class do

  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}

  let(:hiera_data) {{
    'sensu_handlers::teams' => { 'operations' => {} },
    'sensu_handlers::jira_password' => 'from_hiera',
    'sensu_handlers::mailer::mail_from' => 'foo@bar.com',
  }}

  before(:each) do
    Puppet::Parser::Functions.newfunction(:vault_lookup, :type => :rvalue) do |arguments|
      'from_vault_lookup'
    end
  end

  context 'by default' do
    it 'obtains the Jira password from hiera' do
      cfg = catalogue.resource('sensu::handler', 'jira').send(:parameters)[:config]
      expect(cfg['password']).to eq('from_hiera')
    end
  end

  context "when $jira_password_source = 'vault'" do
    let(:hiera_data) { super().merge({ 'sensu_handlers::jira_password_source' => 'vault' }) }
    it 'calls vault_lookup' do
      cfg = catalogue.resource('sensu::handler', 'jira').send(:parameters)[:config]
      expect(cfg['password']).to eq('from_vault_lookup')
    end
  end

end

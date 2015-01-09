require 'spec_helper'

describe 'sensu_handlers', :type => :class do


  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}

  context 'By default, it needs teams to be provided' do
    it { should_not compile }
  end

  context 'With teams' do
    let(:teams) {{
      'operations' => {}
    }}
    let(:params) {{
      :jira_username => 'foo',
      :jira_password => 'bar',
      :jira_site => 'https://jira.mycompany.com',
      :teams     => teams
    }}
    let(:hiera_data) {{
      :'sensu_handlers::teams' => teams
    }}
    it { should compile }
  end

end


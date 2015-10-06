require 'spec_helper'

describe 'sensu_handlers', :type => :class do

  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}

  let(:teams) {{
    'operations' => {}
  }}

  describe "teams" do
    context 'By default, it needs teams to be provided' do
      it { should_not compile }
    end

    context 'With teams' do
      let(:params) {{
        :jira_username => 'foo',
        :jira_password => 'bar',
        :jira_site => 'https://jira.mycompany.com',
        :teams     => teams
      }}
      let(:hiera_data) {{
        :'sensu_handlers::teams'             => teams,
        :'sensu_handlers::mailer::mail_from' => "foo@bar.com"
      }}
      it { should compile }
    end
  end

  describe 'use_embedded_ruby' do
    let(:pre_condition) do
      <<-EOM
        class sensu_handlers::test () inherits sensu_handlers {
          package{'foo': provider => $gem_provider }
        }
      EOM
    end

    let(:params) {{
      :default_handler_array =>  ['test'],
      :use_embedded_ruby     => use_embedded_ruby,
      :teams                 => teams
    }}

    context "when true" do
      let(:use_embedded_ruby)  { true }
      it "sets $gem_provider to sensu_gem" do
        should create_package(:foo).with_provider('sensu_gem')
      end
    end

    context "when false" do
      let(:use_embedded_ruby)  { false }
      it "sets $gem_provider to gem" do
        should create_package(:foo).with_provider('gem')
      end
    end

  end

end


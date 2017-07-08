require 'spec_helper'

describe 'sensu_handlers', type: :class do
  let(:facts) do
    {
      osfamily: 'Debian',
      lsbdistid: 'debian'
    }
  end

  let(:teams) do
    {
      'operations' => {}
    }
  end

  describe 'teams' do
    context 'By default, it needs teams to be provided' do
      it { should_not compile }
    end

    context 'With teams' do
      let(:params) do
        {
          jira_username: 'foo',
          jira_password: 'bar',
          jira_site: 'https://jira.mycompany.com',
          teams: teams
        }
      end
      let(:hiera_data) do
        {
          :'sensu_handlers::teams' => teams,
          :'sensu_handlers::mailer::mail_from' => 'foo@bar.com'
        }
      end
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

    let(:params) do
      {
        default_handler_array: ['test'],
        use_embedded_ruby: use_embedded_ruby,
        teams: teams
      }
    end

    context 'when true' do
      let(:use_embedded_ruby) { true }
      it 'sets $gem_provider to sensu_gem' do
        should create_package(:foo).with_provider('sensu_gem')
      end
    end

    context 'when false' do
      let(:use_embedded_ruby) { false }
      it 'sets $gem_provider to gem' do
        should create_package(:foo).with_provider('gem')
      end
    end
  end

  describe 'api_client_config' do
    let(:hiera_data) do
      {
        'sensu_handlers::teams' => { 'operations' => {} },
        'sensu_handlers::mailer::mail_from' => 'hello@example.com'
      }
    end

    context 'when empty (default)' do
      it {
        should_not contain_file('/etc/sensu/conf.d/api_client.json')
      }
    end

    context 'when set' do
      let(:hiera_data) do
        {
          'sensu_handlers::teams' => { 'operations' => {} },
          'sensu_handlers::mailer::mail_from' => 'hello@example.com',
          'sensu_handlers::api_client_config' => { 'host' => 'foo', 'port' => 12_345 }
        }
      end
      it {
        should contain_file('/etc/sensu/conf.d/api_client.json') \
          .with_content(/"host": "foo"/) \
          .with_content(/"port": 12345/)
      }
    end
  end

  describe 'num_occurrences_filter' do
    let(:hiera_data) do
      {
        'sensu_handlers::teams' => { 'operations' => {} },
        'sensu_handlers::mailer::mail_from' => 'hello@example.com'
      }
    end

    context 'by default' do
      it {
        should_not contain_file('/etc/sensu/extensions/num_occurrences_filter.rb')
        should contain_sensu__handler('jira') \
          .with_filters(['ticket_filter'])
        should contain_sensu__handler('pagerduty') \
          .with_filters(['page_filter'])
        should contain_sensu__handler('nodebot').with_filters([])
        should contain_sensu__handler('mailer').with_filters([])
      }
    end

    context 'when use_num_occurrences_filter is set to true' do
      let(:params) { { use_num_occurrences_filter: true } }
      it {
        should contain_file('/etc/sensu/extensions/num_occurrences_filter.rb')
        should contain_sensu__handler('jira') \
          .with_filters(%w[ticket_filter num_occurrences_filter])
        should contain_sensu__handler('pagerduty') \
          .with_filters(%w[page_filter num_occurrences_filter_for_pagerduty])
        should contain_sensu__handler('nodebot') \
          .with_filters(['num_occurrences_filter'])
        should contain_sensu__handler('mailer') \
          .with_filters(['num_occurrences_filter'])
      }
    end
  end
end

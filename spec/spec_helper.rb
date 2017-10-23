require 'rubygems'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'hiera-puppet-helper'
require 'rspec-hiera-hotfix.rb'

RSpec.configure do |config|
  config.mock_framework = :rspec
end

module Sensu
  class Handler
    attr_accessor :event
  end
end

module SensuHandlerTestHelper
  def settings_key
    subject.class.to_s.downcase
  end

  def setup_event!(event = nil)
    event ||= {}
    event['occurrences']     ||= 1
    event['check']           ||= {}
    event['client']          ||= {}
    event['client']['name']  ||= 'some.client'
    event['check']['name']   ||= 'mycoolcheck'
    event['check']['status'] ||= 0
    event['check']['output'] ||= 'some check output'
    event['check']['issued'] ||= Time.now
    event['check']['region'] = 'someregion'
    subject.event = event
    subject.settings = ({})
    subject.settings['default'] = {}
    subject.settings['default']['dashboard_link'] = 'test_dashboard_link'
    subject.settings['default']['datacenter'] = 'data_center'
    subject.settings[settings_key] ||= {}
    subject.settings[settings_key]['teams'] ||= {}
    subject.settings[settings_key]['teams']['operations'] = {
      'pagerduty_api_key' => 'operations_pagerduty_key'
    }
    subject.settings[settings_key]['teams']['someotherteam'] = {
      'pagerduty_api_key' => 'someotherteam_pagerduty_key'
    }
    subject.settings[settings_key]['teams']['team_with_tags'] = {
      'tags' => %w[test_team_tag test_team_tag_2]
    }
    yield(event) if block_given?
  end
end

RSpec::Matchers.define :exit_with_code do |exp_code|
  actual = nil
  match do |block|
    begin
      block.call
    rescue SystemExit => e
      actual = e.status
    end
    actual && actual == exp_code
  end
  failure_message_for_should do |_block|
    "expected block to call exit(#{exp_code}) but exit" +
      (actual.nil? ? ' not called' : "(#{actual}) was called")
  end
  failure_message_for_should_not do |_block|
    "expected block not to call exit(#{exp_code})"
  end
  description do
    "expect block to call exit(#{exp_code})"
  end
end

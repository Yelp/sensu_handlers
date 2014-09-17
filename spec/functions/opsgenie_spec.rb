require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

module Sensu
  class Handler
    attr_accessor :event
  end
end

require "#{File.dirname(__FILE__)}/../../files/opsgenie"

class Opsgenie
  attr_accessor :settings
end

describe Opsgenie do
  include SensuHandlerTestHelper

  subject { Opsgenie.new }
  before(:each) { setup_event! }

  it "Doesn't work without providing a team" do
    setup_event!
    expect(subject).not_to receive(:create_alert)
  end

  it "works for custom team" do
    # This team metadata is specified in the spec helper
    setup_event! { |e| e['check']['team'] = '3rd_test_team' }
    subject.team_name.should == '3rd_test_team'
    subject.api_key.should == '3rd_teams_ops_genie_api_key'
  end

  context "Events set to page, but withot an API key" do
    before(:each) { 
      subject.event['check']['page'] = true 
      subject.event['check']['team'] = 'team_without_og_key'
    }
    it "shouldn't page" do
      setup_event! do |e|
        subject.event['check']['status'] = 2
      end
      expect(subject).not_to receive(:create_alert)
    end
   end

  context "Events set to page, but without team recipients" do
    before(:each) { 
      subject.event['check']['page'] = true 
      subject.event['check']['team'] = 'team_without_og_recipients'
    }
    it "shouldn't page" do
      setup_event! do |e|
        subject.event['check']['status'] = 2
      end
      expect(subject).not_to receive(:create_alert)
    end
   end

  context "events which page" do
    before(:each) { 
      subject.event['check']['page'] = true 
      subject.event['check']['team'] = '3rd_test_team'
    }

    it "Event resolved in opsgenie if OK" do
      expect(subject).to receive(:close_alert).and_return(true)
      subject.handle
    end

   it "Event sent to opsgenie if critical" do
     subject.event['check']['status'] = 2
     expect(subject).to receive(:create_alert).and_return(true)
     subject.handle
   end

    it "Event resolved in opsgenie if WARNING" do
      subject.event['status'] = 1
      expect(subject).to receive(:close_alert).and_return(true)
      subject.handle
    end
  end

  it "has notification as description, with runbook" do
    setup_event! do |e|
      e['check']['notification'] = 'some_notification'
      e['check']['status'] = 2
      e['check']['runbook'] = 'http://my.runbook'
    end
    subject.description.should == 'some_notification (http://my.runbook)'
  end

  it "has default client/check/output as description, with runbook" do
    setup_event! do |e|
      e['check']['status'] = 2
      e['check']['runbook'] = 'http://my.runbook'
    end
    subject.description.should == 'some.client : mycoolcheck : some check output (http://my.runbook)'
  end

  it "has default client/check/output as description, without runbook" do
    setup_event! { |e| e['check']['runbook'] = nil; e['check']['status'] = 2 }
    subject.description.should == 'some.client : mycoolcheck : some check output'
  end

  it "has no runbook when event is in OK state" do
    subject.description.should == 'some.client : mycoolcheck : some check output'
  end

end


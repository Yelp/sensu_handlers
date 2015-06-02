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

require "#{File.dirname(__FILE__)}/../../files/pagerduty"

class Pagerduty
  attr_accessor :settings, :timeout_count, :logged
  def timeout(t)
    if timeout_count && timeout_count >= 1
      @timeout_count = @timeout_count - 1
      raise Timeout::Error
    else
      yield
    end
  end

  def log(line)
    @logged = line
  end

  def do_sleep
  end
end

describe Pagerduty do
  include SensuHandlerTestHelper

  subject { Pagerduty.new }
  before(:each) { setup_event! }

  it "Doesn't work without providing a team" do
    setup_event!
    expect(subject).not_to receive(:trigger_incident)
  end

  it "works for custom team" do
    setup_event! { |e| e['check']['team'] = 'someotherteam' }
    subject.team_name.should == 'someotherteam'
    subject.api_key.should == 'someotherteam_pagerduty_key'
  end

  context "events which page" do
    before(:each) { subject.event['check']['page'] = true }

    it "Event resolved in pagerduty if OK" do
      expect(subject).to receive(:resolve_incident).and_return(true)
      subject.handle
    end

   it "Event sent to pagerduty if critical" do
     subject.event['check']['status'] = 2
     expect(subject).to receive(:trigger_incident).and_return(true)
     subject.handle
   end

    it "Event resolved in pagerduty if WARNING" do
      subject.event['status'] = 1
      expect(subject).to receive(:resolve_incident).and_return(true)
      subject.handle
    end

    context "Pagerduty times out / errors" do
      before(:each) do
        subject.event['check']['status'] = 2
        subject.event['check']['team'] = 'operations'
      end
      it "logs an error when we time out 3 times" do
        subject.timeout_count = 4
        subject.handle
        expect(subject.logged).to eql('pagerduty -- timed out while attempting to trigger an incident -- sensu somehabitat some.client mycoolcheck')
      end
      it "can succeed if we time out once" do
        subject.timeout_count = 1
        expect(subject).to receive(:trigger_incident).and_return(true)
        subject.handle
      end
      it "can succeed if we time out twice" do
        subject.timeout_count = 2
        expect(subject).to receive(:trigger_incident).and_return(true)
        subject.handle
      end
      it "Fails if we error 3 times" do
        expect(subject).to receive(:trigger_incident).and_return(false, false, false)
        subject.handle
        expect(subject.logged).to eql('pagerduty -- failed to trigger incident -- sensu somehabitat some.client mycoolcheck')
      end
      it "Succeeds if we error 2 times" do
        expect(subject).to receive(:trigger_incident).and_return(false, false, true)
        subject.handle
        expect(subject.logged).to eql('pagerduty -- Triggerd incident -- sensu somehabitat some.client mycoolcheck')
      end
      it "Succeeds if we timeout then error once" do
        subject.timeout_count = 1
        expect(subject).to receive(:trigger_incident).and_return(false, true)
        subject.handle
        expect(subject.logged).to eql('pagerduty -- Triggerd incident -- sensu somehabitat some.client mycoolcheck')
      end
    end
  end

  context "events which do not page" do
    before(:each) do
      subject.event['check']['page'] = false
    end
    it "Does not trigger an incident" do
      subject.event['check']['status'] = 2
      expect(subject).not_to receive(:trigger_incident)
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

  context "Does not use the operations api key if team does not have one set" do
    it do
      subject.settings[settings_key]['teams']['newteam'] = {}
      subject.event['check']['page'] = true
      subject.event['check']['team'] = 'newteam'
      expect(subject.api_key).not_to eql('operations_pagerduty_key')
    end
  end
end


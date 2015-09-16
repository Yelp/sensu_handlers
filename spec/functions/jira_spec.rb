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

require "#{File.dirname(__FILE__)}/../../files/jira"

class Jira
  attr_accessor :settings
end

describe Jira do
  include SensuHandlerTestHelper

  subject { Jira.new }
  before(:each) { setup_event! }

  it "Doesn't work without providing ticket=>true" do
    setup_event!
    expect(subject).not_to receive(:create_issue)
  end

  it "By default should not ticket issues" do
    setup_event!
    subject.should_ticket? == false
  end

  it "Works for custom Jira Project" do
    subject.event['check']['team'] = 'custom_team'
    subject.event['check']['ticket'] = true
    subject.event['check']['status'] = 2
    subject.event['check']['name'] = 'fake_alert'
    subject.event['client']['name'] = 'fake_client'
    subject.event['check']['project'] = 'CUSTOM'
    expect(subject).to receive(:create_issue).with("fake_alert on fake_client is CRITICAL", /.*/, "CUSTOM").and_return(true)
    expect(subject).not_to receive(:close_issue)
    subject.handle
  end

  it "Wont make a ticket if it doesn't have a project available" do
    subject.event['check']['ticket'] = true
    subject.event['check']['status'] = 2
    subject.event['check']['team'] = "bla"
    expect(subject).not_to receive(:create_issue)
    expect(subject).not_to receive(:close_issue)
    subject.handle
  end

  context "With events that DO have ticket => true and a valid project" do
    before(:each) { subject.event['check']['ticket'] = true 
                    subject.event['check']['project'] = 'TEST'
                    subject.event['check']['team'] = 'custom_team'
                  }

    it "Event resolved in Jira if OK" do
      subject.event['status'] = 0
      expect(subject).to receive(:close_issue).and_return(true)
      subject.handle
    end

    it "Event sent to Jira if critical" do
      subject.event['check']['status'] = 2
      expect(subject).to receive(:create_issue).and_return(true)
      subject.handle
    end

    it "Event created in Jira if WARNING" do
      subject.event['check']['status'] = 1
      expect(subject).to receive(:create_issue).and_return(true)
      subject.handle
    end

    it "Tags exists in the Event" do
      subject.event['check']['status'] = 2
      subject.event['check']['tags'] = ["some_tag"]
      expect(subject.build_labels).to match_array(["SENSU", "SENSU_mycoolcheck", "SENSU_some.client", "some_tag"])
      expect(subject).to receive(:create_issue).and_return(true)
      subject.handle
    end

  end

end


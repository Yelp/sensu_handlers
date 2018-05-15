
require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

require "#{File.dirname(__FILE__)}/../../files/slack"

class Slack
  attr_accessor :settings
end

describe Slack do
  include SensuHandlerTestHelper

  # because we are in spec/functions we have included 
  # Rspec::Puppet::FunctionExampleGroup which has taken over subject
  subject { described_class.new }

  let(:team)             { 'testteam1' }
  let(:settings)         { subject.settings[settings_key] }
  let(:handler_settings) { subject.handler_settings }
  let(:check_data)       { subject.event['check'] }
  let(:client_data)      { subject.event['client'] }
  let(:team_settings)    { settings['teams'][team] }

  before do
    setup_event!
    settings['teams'][team] = Hash.new
    check_data['team']      = 'testteam1'
    check_data['issued']    = 1438866190
  end


  # two silly tests just for starter
  specify { expect(subject).to be_a BaseHandler }
  specify { expect(subject).to be_a Sensu::Handler }

  describe "channels" do
    let(:channels) { subject.channels } 
    context "event has page true" do
      before { check_data['page'] = true }

      context "team data has pages_slack_chanel" do
        before  { team_settings['pages_slack_channel'] = 'pager-channel' }
        specify { expect(channels).to eql ['pager-channel'] }
      end

      context "team data does not have pager_slack_chanel" do
        specify { expect(channels).to eql ["##{team}-pages"] }
      end

    end

    context "check data has slack_channels" do
      before  { check_data['slack_channels'] = 'check-channel' }
      specify { expect(channels).to eql ["check-channel"] }
    end
  end

  describe "compact_messages" do
    let(:compact_messages) { subject.compact_messages }

    context "handler settings compact_message is not set" do
      context "when slack_compact_message is true in team data" do
        before  { team_settings['slack_compact_message'] = true  }
        specify { expect(compact_messages).to be_true }
      end

      context "when slack_compact_message is false in team data" do
        before  { team_settings['slack_compact_message'] = false  }
        specify { expect(compact_messages).to be_false }
      end

      context "when slack_compact_message is not set in  team data" do
        specify { expect(compact_messages).to be_false }
      end
    end

    context "handler settings compact_message is true" do
      before { handler_settings['compact_message'] = true }

      context "when slack_compact_message is true in team data" do
        before  { team_settings['slack_compact_message'] = true  }
        specify { expect(compact_messages).to be_true }
      end

      context "when slack_compact_message is false in team data" do
        before  { team_settings['slack_compact_message'] = false  }
        specify { expect(compact_messages).to be_false }
      end

      context "when slack_compact_message is not set in  team data" do
        specify { expect(compact_messages).to be_true }
      end
    end

    context "handler settings compact_message is false" do
      before { handler_settings['compact_message'] = false }

      context "when slack_compact_message is true in team data" do
        before  { team_settings['slack_compact_message'] = true  }
        specify { expect(compact_messages).to be_true }
      end

      context "when slack_compact_message is false in team data" do
        before  { team_settings['slack_compact_message'] = false  }
        specify { expect(compact_messages).to be_false }
      end

      context "when slack_compact_message is not set in  team data" do
        specify { expect(compact_messages).to be_false }
      end
    end

  end

end

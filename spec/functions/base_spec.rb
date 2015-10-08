require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

require "#{File.dirname(__FILE__)}/../../files/base"

class BaseHandler
  attr_accessor :settings
end

describe BaseHandler do
  include SensuHandlerTestHelper

  subject { BaseHandler.new }

  before(:each) { setup_event! }

  context "works with simplest check with no metadata" do
    it('is ok') { expect(subject.event_is_ok?).to eql(true) }
    it('is not critical') { expect(subject.event_is_critical?).to eql(false) }
    it('is not warning') { expect(subject.event_is_warning?).to eql(false) }
    it('does not page by default') { expect(subject.should_page?).to eql(false) }
    it('has no runbook') { expect(subject.runbook).to eql(false) }
  end

  context "dashboard link is correctly compiled" do
    it('has correct link') { expect(subject.dashboard_link).to eql('test_dashboard_link/#/client/data_center/some.client?check=mycoolcheck') }
  end

  context "Settings can be overridden from check metadata" do
    before(:each) do
      setup_event! do |e|
        e['check']['status'] = 2
        e['check']['page'] = true
        e['check']['runbook'] = 'http://some.runbook/'
        e['check']['team'] = 'someotherteam'
      end
    end
    it('is critical') { expect(subject.event_is_critical?).to eql(true) }
    it('pages') { expect(subject.should_page?).to eql(true) }
    it('has a runbook') { expect(subject.runbook).to eql('http://some.runbook/') }
    it('belongs to another team') { expect(subject.team_name).to eql('someotherteam') }
  end

  context "testing team_data method" do
    before(:each) do
      setup_event! do |e|
        e['check']['team'] = 'operations'
      end
    end
    context "has a team_data method that pulls raw team data back" do
      it('returns data') { expect(subject.team_data).to eql({'pagerduty_api_key' => 'operations_pagerduty_key'}) }
      it('passes data to block') do
        subject.team_data { |data| expect(data).to eql({'pagerduty_api_key' => 'operations_pagerduty_key'}) }
      end
      it('does not barf if unknown key') do
        expect { subject.team_data('unknown_key') }.to_not raise_error()
        mock_do_not_call = double()
        expect(mock_do_not_call).to_not receive(:in_block)
        expect do
          subject.team_data('unknown_key') { |data| mock_do_not_call.in_block(data) }
        end.to_not raise_error()
      end
    end
    context "has a team_data method that can find a sub-key" do
      it('returns data') { expect(subject.team_data('pagerduty_api_key')).to eql('operations_pagerduty_key') }
      it('passes data to block') do
        subject.team_data('pagerduty_api_key') { |data| expect(data).to eql('operations_pagerduty_key') }
      end
    end
    context "works if no team data" do
      before(:each) do
        setup_event! { |e| e['check']['team'] = 'unknownteam' }
      end
      it('returns empty hash when no team data') { expect(subject.team_data).to eql({}) }
      it('returns nil for unknown field') { expect(subject.team_data('unknown_key')).to eql(nil) }
    end
  end

  context "check description" do
    context "notification overrides" do
      before(:each) do
        setup_event! { |e| e['check']['notification'] = 'some notification' }
      end
      it { expect(subject.description).to eql('some notification') }
    end
    context '\n stripped' do
      before(:each) do
        setup_event! { |e| e['check']['notification'] = "some\nnotification" }
      end
      it { expect(subject.description).to eql('some notification') }
    end
    context 'default description' do
      it { expect(subject.description).to eql('some.client : mycoolcheck : some check output') }
    end
    context 'runbook and tip only when warning or critical' do
      before(:each) do
        setup_event! do |e|
          e['check']['runbook'] = 'http://some.runbook'
          e['check']['tip'] = 'Do not eat cheese before bed'
        end
      end
      it("has default desc when ok") { expect(subject.description).to eql('some.client : mycoolcheck : some check output') }
      [1, 2].each do |status|
        it("has runbook and tip when warning") do
          subject.event['check']['status'] = status
          expect(subject.description).to \
            eql('some.client : mycoolcheck : some check output - Do not eat cheese before bed (http://some.runbook)')
        end
      end
    end
    context 'handles character limit when needed' do
      before(:each) do
        setup_event! do |e|
          e['check']['status'] = 2
          e['check']['runbook'] = 'http://some.runbook'
          e['check']['tip'] = 'Reee' + 'e'*1000 + 'ly long tip'
        end
      end
      it { expect(subject.description(42).length).to eq(42) }
    end
  end

  context "full_description" do
    before(:each) do
      setup_event! do |e|
        e['check']['status'] = 2
        e['check']['page'] = true
        e['check']['runbook'] = 'http://some.runbook/'
        e['check']['team'] = 'someotherteam'
      end
    end
    it "should correctly format the output" do
      expect(subject.full_description).to include("Team: someotherteam")
      expect(subject.full_description).to include("Status: CRITICAL (2)")
    end
  end

  context "Color filtering" do
     before(:each) do
      setup_event! do |e|
        e['check']['runbook'] = 'http://some.runbook/'
        e['check']['team'] = 'someotherteam'
        e['check']['output'] = '[36mTEST[36mOUTPUT[0m'
      end
    end
    it "should strip the colors in full_description" do
      expect(subject.full_description).to match("^TESTOUTPUT\n")
    end
    it "should strip the colors in description" do
      expect(subject.full_description_hash['Output']).to match("^TESTOUTPUT$")
    end
  end

  context "check filter_repeated" do
    before(:each) do
      setup_event!
    end
    context "It should not fire before alert_after" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 60
        subject.event['check']['alert_after'] = 120
        subject.event['check']['realert_every'] = "1"
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "It should not fire an alert after one alert_after period, because that would be the same as alert_after = 0" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 60
        subject.event['check']['alert_after'] = 60
        subject.event['check']['realert_every'] = "100000"
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "It should fire an alert after it first reaches the alert_after, regardless of the realert_every" do
      it do
        subject.event['occurrences'] = 3
        subject.event['check']['interval'] = 60
        subject.event['check']['alert_after'] = 120
        subject.event['check']['realert_every'] = "100000"
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "It should fire an alert after the first check, even if alert_after == 0" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 10
        subject.event['check']['alert_after'] = 0
        subject.event['check']['realert_every'] = "30"
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "It should fire an event after the first check, if alert_after == 0 and realert_every 1" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 10
        subject.event['check']['alert_after'] = 0
        subject.event['check']['realert_every'] = 1
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "interval 0 no divide by 0 error" do
      it do
        subject.event['occurrences'] = 2
        subject.event['check']['interval'] = 0
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, it should alert the first time" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, it should alert the second time" do
      it do
        subject.event['occurrences'] = 2
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, it should not alert the third time" do
      it do
        subject.event['occurrences'] = 3
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, it should alert the 4th time" do
      it do
        subject.event['occurrences'] = 4
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, it should not alert the 5th time" do
      it do
        subject.event['occurrences'] = 5
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should not alert the first time" do
      it do
        subject.event['occurrences'] = 1
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should not alert the second time" do
      it do
        subject.event['occurrences'] = 2
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should not alert the third time" do
      it do
        subject.event['occurrences'] = 3
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should alert the forth time" do
      it do
        subject.event['occurrences'] = 4
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should not alert the fith time" do
      it do
        subject.event['occurrences'] = 5
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "When exponential backoff, and alert_after, it should not alert the sixth time" do
      it do
        subject.event['occurrences'] = 6
        subject.event['check']['interval'] = 20
        subject.event['check']['realert_every'] = "-1"
        subject.event['check']['alert_after'] = 60
        subject.event['action'] = 'create'
        expect(subject).to receive(:bail).and_return(nil).once
        expect(subject.filter_repeated).to eql(nil)
      end
    end
    context "when realert_every is not set" do
      it "treats realert_every as 1" do
        subject.event['occurrences'] = 6
        subject.event['check']['interval'] = 20
        subject.event['check']['alert_after'] = 60
        subject.event['check'].delete('realert_every')
        subject.event['action'] = 'create'
        expect(subject).not_to receive(:bail)
        expect(subject.filter_repeated).to eql(nil)
      end
    end
  end #End filter repeated

  context "With display name tag" do
    context "When display tag is not set" do
      before(:each) do
        setup_event! { |e|
          e['client']['name'] = 'foo.bar'
          e['client']['tags'] = { }
        }
      end
      it {
        expect(subject.description).to match(/^foo.bar :/)
      }
    end

    context "When display tag is set to empty string" do
      before(:each) do
        setup_event! { |e|
          e['client']['name'] = 'foo.bar'
          e['client']['tags'] = { 'Display Name' => '' }
        }
      end
      it {
        expect(subject.description).to match(/^foo.bar :/)
      }
    end

    context "When display tag is set" do
      before(:each) do
        setup_event! { |e|
          e['client']['name'] = 'foo.bar'
          e['client']['tags'] = { 'Display Name' => 'baz.qux' }
        }
      end
      it {
        expect(subject.description).to match(/^baz.qux :/)
      }
    end
  end # End of context 'With display name tag'


  describe "#channels" do
    let(:team)       { 'someteam' }
    let(:settings)   { subject.settings[settings_key] }
    let(:team_data)  { settings['teams'][team] }
    let(:check_data) { subject.event['check'] }
    let(:channels)   { subject.channels }

    before do
      setup_event!({
        'check' => { 'team' => team }
      })

      # must come after setup_event!
      settings['teams'][team] = {}
    end


    context "when event is set to page" do
      before { check_data['page'] = true }

      context "with no team or event level config"  do
        it { expect(channels).to eq [] }
      end

      context "with both notification and pager channels configured at team leavel" do
        before do
          team_data['channel']       = 'notify_channel'
          team_data['pager_channel'] = 'pager_channel'
        end

        context "with no config at event level"  do
          it "returns both the pager and notification channels" do
            expect(channels).to eq ['pager_channel', 'notify_channel']
          end
        end

        context "with channel set at event level" do
          before { check_data['channel'] = 'notify_channel_from_event' }
          it "prefers event channel" do
            expect(channels).to eq ['pager_channel', 'notify_channel_from_event']
          end
        end

        context "with pager_channel set at event level" do
          before { check_data['pager_channel'] = 'pager_channel_from_event' }
          it "prefers event pager_channel" do
            expect(channels).to eq ['pager_channel_from_event', 'notify_channel']
          end
        end
      end

      context "alternate key names" do
        before do
          team_data['room']       = 'notify_channel'
          team_data['pager_room'] = 'pager_channel'
        end
        it "returns both the pager and notification channels" do
          expect(channels).to eq ['pager_channel', 'notify_channel']
        end
      end

      context "when configured with lists of channels" do
        before do
          team_data['channel']       = ['notify_channel', 'notify_channel2']
          team_data['pager_channel'] = ['pager_channel', 'pager_channel2']
          check_data['channel']      = ['notify_channel_from_event', 'blah']
        end
        it "returns all the pager and notification channels" do
          expect(channels).to eq [
            'pager_channel',
            'pager_channel2',
            'notify_channel_from_event',
            'blah'
          ]
        end
      end
    end

    context "when event is not set to page" do
      before { check_data.delete('page') }

      context "with no team or event config" do
        it { expect(channels).to eq [] }
      end

      context "with team channel configured" do
        before do
          team_data['channel']       = 'notify_channel'
          team_data['pager_channel'] = 'pager_channel'
        end

        context "and no event channel configured" do
          it { expect(channels).to eq ['notify_channel'] }
        end

        context "and event channel configured" do
          before { check_data['channel'] = 'notify_channel_from_event' }
          it "prefers event channel" do
            expect(channels).to eq ['notify_channel_from_event']
          end
        end
      end

    end


  end


end # End describe

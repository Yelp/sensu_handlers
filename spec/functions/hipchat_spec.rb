require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

require "#{File.dirname(__FILE__)}/../../files/hipchat"

class Hipchat
  attr_accessor :settings
end

describe Hipchat do
  include SensuHandlerTestHelper

  # because we are in spec/functions we have included 
  # Rspec::Puppet::FunctionExampleGroup which has taken over subject
  subject { described_class.new }

  let(:team)             { 'testteam1' }
  let(:settings)         { subject.settings[settings_key] }
  let(:handler_settings) { subject.handler_settings }
  let(:check_data)       { subject.event['check'] }
  let(:client_data)      { subject.event['client'] }
  #let(:team_data)       { settings['teams'][team] }

  before(:each) do
    setup_event!
    check_data['team']   = 'testteam1'
    check_data['issued'] = 1438866190

    settings['teams'][team] = {
      'hipchat_room' => 'Test team #1'
    }
  end


  # two silly tests just for starter
  it { expect(subject).to be_a BaseHandler }
  it { expect(subject).to be_a Sensu::Handler }

  describe 'trigger_incident' do
    let(:trigger_incident) { subject.trigger_incident }

    context "with no hipchat api_key" do
      it 'returns false' do
        expect(trigger_incident).to be false
      end
    end

    context "with hipchat api_key" do

      before do
        handler_settings['api_key'] = 'fakekey'
        check_data['status'] = 2
      end

      it 'calls alert_hipchat when hipchat api_key exists' do
        expect(subject).to receive(:alert_hipchat) \
          .once \
          .with(
          'Test team #1',
          'sensu',
          include(
            "2015-08-06 13:03:10 UTC",
            "mycoolcheck on some.client",
            "CRITICAL",
            "some check output"
          ),
          hash_including(:color => "red", :notify => true)
        )

        trigger_incident
      end

      context "with lists of rooms for notifications" do
        before do
          settings['teams'][team] = {
            'pager_room' => ['pager_room1', 'pager_room2'],
            'room'       => ['room1', 'room2']
          }
          check_data['room'] = ['event_room1', 'event_room2']
          check_data['page'] = true
        end

        def alert_room(room)
          receive(:alert_hipchat).with(room, anything, anything, anything)
        end
        it "notifies the appropriate rooms" do
          expect(subject).to alert_room('pager_room1')
          expect(subject).to alert_room('pager_room2')
          expect(subject).to alert_room('event_room1')
          expect(subject).to alert_room('event_room2')

          trigger_incident
        end
      end
    end
  end

  describe 'resolve_incident' do
    let(:resolve_incident) { subject.resolve_incident }

    context "with no hipchat api_key" do
      it "returns false" do
        expect(resolve_incident).to be false
      end
    end

    context "with hipchat api_key" do
      before do
        handler_settings['api_key'] = 'fakekey'
        check_data['status'] = 0
      end

      it 'calls alert_hipchat when hipchat api_key exists' do

        expect(subject).to receive(:alert_hipchat) \
          .once \
          .with(
            'Test team #1',
            'sensu',
            include(
              "2015-08-06 13:03:10 UTC",
              "mycoolcheck on some.client",
              "OK",
              "some check output"
            ),
            hash_including(:color => "green")
          )

        resolve_incident
      end
    end
  end

  describe 'handle' do
    before { handler_settings['api_key'] = 'fakekey' }
    after  { subject.handle } # note! 

    context 'when check status is 0' do
      before { check_data['status'] = 0 }

      it 'calls resolve_incident' do
        expect(subject).to receive(:resolve_incident) \
          .once \
          .and_return(true)
      end

      it 'calls alert_hipchat with options color green' do
        expect(subject).to receive(:alert_hipchat) \
          .once \
          .with(
            'Test team #1',
            'sensu',
            include(
              "2015-08-06 13:03:10 UTC",
              "mycoolcheck on some.client",
              "OK",
              "some check output"
            ),
            hash_including(:color => "green")
          ) \
          .and_return(true)
      end

    end

    context 'when check status is 1' do
      before { check_data['status'] = 1 }

      it 'calls trigger_incident once' do
        expect(subject).to receive(:trigger_incident) \
          .once \
          .and_return(true)
      end

      it 'calls alert_hipchat with options color yellow & notify true' do
        expect(subject).to receive(:alert_hipchat) \
          .once \
          .with(
            'Test team #1',
            'sensu',
            include(
              "2015-08-06 13:03:10 UTC",
              "mycoolcheck on some.client",
              "WARNING",
              "some check output"
            ),
            { :color => 'yellow', :notify => true }
          ) \
          .and_return(true)
      end
    end

    context 'when check status is 2' do
      before { check_data['status'] = 2 }

      it 'calls trigger_incident' do
        expect(subject).to receive(:trigger_incident) \
          .once \
          .and_return(true)

      end


      it 'calls alert_hipchat with options color red & notify true' do
        expect(subject).to receive(:alert_hipchat) \
          .once \
          .with(
            'Test team #1',
            'sensu',
            include(
              "2015-08-06 13:03:10 UTC",
              "mycoolcheck on some.client",
              "CRITICAL",
              "some check output"
            ),
            { :color => 'red', :notify => true }
          ) \
          .and_return(true)

      end
    end
  end

  describe 'hipchat_message' do
    let(:hipchat_message) { subject.hipchat_message }
    before do
      check_data['name']     = 'Fake Service port 80'
      check_data['issued']   = 1438866190
      client_data['name']    = 'test.vagrant.local'
      client_data['address'] = '127.0.0.1'
    end

    it 'correctly formats the check issued date' do
      expect(hipchat_message).to include('2015-08-06 13:03:10 UTC')
    end

    it 'correctly formats the line containing datetime, service, host and address' do
      expect(hipchat_message).to \
        include('2015-08-06 13:03:10 UTC - Fake Service port 80 on test.vagrant.local (127.0.0.1)')
    end

    context 'when check notification is populated' do
      it 'contains the notifcation data' do
        expect(hipchat_message).to include('some check output')
      end
    end

    context 'when check notification is absent from sensu data' do
      before do
        check_data['output'] = 'TCP OK - 0.019 second response time on port 80'
        check_data.delete('notification')
      end

      it 'contains the check output' do
        expect(hipchat_message).to include('TCP OK - 0.019 second response time on port 80')
      end
    end

    context 'human readable message status' do
      context 'when status is 0' do
        before { check_data['status'] = 0 }

        it 'status message is OK' do
          expect(hipchat_message).to include(' - OK')
        end
      end

      context 'when status is 1' do
        before { check_data['status'] = 1 }

        it 'status message is WARNING' do
          expect(hipchat_message).to include(' - WARNING')
        end
      end

      context 'when status is 2' do
        before { check_data['status'] = 2 }

        it 'status message is CRITICAL' do
          expect(hipchat_message).to include(' - CRITICAL')
        end
      end

      context 'when status is 3' do
        before { check_data['status'] = 3 }

        it 'status message is UNKNOWN' do
          expect(hipchat_message).to include(' - UNKNOWN')
        end
      end
    end
  end

end

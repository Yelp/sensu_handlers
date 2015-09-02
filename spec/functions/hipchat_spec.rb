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

  subject { described_class.new }
  before(:each) { setup_event! }

  # two silly tests just for starter
  it { expect(subject).to be_a BaseHandler }
  it { expect(subject).to be_a Sensu::Handler }

  describe 'trigger_incident' do
    it 'returns false when no hipchat api_key' do
      expect(subject.trigger_incident).to be false
    end

    it 'returns true when hipchat api_key exists' do
      subject.settings['hipchat']['apikey'] = 'fakekey'
      expect(subject.trigger_incident).to be true
    end
  end

  describe 'resolve_incident' do
    it 'returns false when no hipchat api_key' do
      expect(subject.resolve_incident).to be false
    end

    it 'returns true when hipchat api_key exists' do
      subject.settings['hipchat']['apikey'] = 'fakekey'
      expect(subject.resolve_incident).to be true
    end
  end

  describe 'handle' do
    context 'when check status is 0' do
      before do
        subject.event['check']['status'] = 0
      end

      context 'when resolve_incident returns true' do
        it 'calls resolve_incident once' do
          expect(subject).to receive(:resolve_incident)
            .once
            .and_return(true)

          subject.handle
        end

        it 'calls alert_hipchat with options color green' do
          expect(subject).to receive(:alert_hipchat)
            .with( { :color => 'green' } )
            .and_return(true)

          subject.handle
        end
      end

      context 'when resolve_incident returns false' do
        it 'calls resolve_incident 3 times' do
          expect(subject).to receive(:resolve_incident)
            .exactly(3).times
            .and_return(false)

          subject.handle
        end
      end
    end

    context 'when check status is 1' do
      before do
        subject.event['check']['status'] = 1
      end

      context 'when trigger_incident returns true' do
        it 'calls trigger_incident once' do
          expect(subject).to receive(:trigger_incident)
            .once
            .and_return(true)

          subject.handle
        end
      end

      context 'when trigger_incident returns false' do
        it 'calls trigger_incident 3 times' do
          expect(subject).to receive(:trigger_incident)
            .exactly(3).times
            .and_return(false)

          subject.handle
        end
      end

      it 'calls alert_hipchat with options color yellow & notify true' do
        expect(subject).to receive(:alert_hipchat)
          .with( { :color => 'yellow', :notify => true } )
          .and_return(true)

        subject.handle
      end
    end

    context 'when check status is 2' do
      before do
        subject.event['check']['status'] = 2
      end

      context 'when trigger_incident returns true' do
        it 'calls trigger_incident once' do
          expect(subject).to receive(:trigger_incident)
            .once
            .and_return(true)

          subject.handle
        end
      end

      # context 'when trigger_incident returns false' do
      #   it 'calls trigger_incident 3 times' do
      #     expect(subject).to receive(:trigger_incident)
      #       .exactly(3).times
      #       .and_return(false)
      #
      #     subject.handle
      #   end
      # end

      it 'calls alert_hipchat with options color red & notify true' do
        expect(subject).to receive(:alert_hipchat)
          .with( { :color => 'red', :notify => true } )
          .and_return(true)

        subject.handle
      end
    end
  end
end

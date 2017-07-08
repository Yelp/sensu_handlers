require 'spec_helper'

module Sensu::Extension
  class Filter
  end
end

require "#{File.dirname(__FILE__)}/../../files/num_occurrences_filter"

describe Sensu::Extension::NumOccurrences do
  subject { Sensu::Extension::NumOccurrences.new }

  context 'without argument' do
    it 'should raise exception' do
      expect { subject.filter_by_num_occurrences }.to raise_error
    end
  end

  context 'when not failing long enough' do
    it 'should return STOP_PROCESSING' do
      event = {
        check: {
          interval: 60,
          alert_after: 300
        },
        occurrences: 2
      }
      expect(subject.filter_by_num_occurrences(event).first).to eql(
        Sensu::Extension::NumOccurrences::STOP_PROCESSING
      )
      expect(subject.filter_by_num_occurrences(event).last).to match(
        /Not failing long enough/
      )
    end
  end

  context 'exponential backoff' do
    event = {
      check: {
        interval: 60,
        alert_after: 300,
        realert_every: -1
      },
      action: :create
    }

    it 'when not on power of two, should return STOP_PROCESSING' do
      [15, 24].each do |i|
        expect(subject.filter_by_num_occurrences(
          event.merge(occurrences: i)
        ).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(
          event.merge(occurrences: i)
        ).last).to match(
          /not on a power of two/
        )
      end
    end

    it 'when on power of two, should return ALLOW_PROCESSING' do
      expect(subject.filter_by_num_occurrences(
        event.merge(occurrences: 261)
      ).first).to eql(
        Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
      )
      expect(subject.filter_by_num_occurrences(
        event.merge(occurrences: 261)
      ).last).to match(
        /can be processed/
      )
    end
  end

  context 'with realert_every' do
    it 'should return STOP_PROCESSING' do
      event = {
        check: {
          interval: 60,
          alert_after: 300,
          realert_every: 60
        },
        action: :create,
        occurrences: 99
      }

      expect(subject.filter_by_num_occurrences(event).first).to eql(
        Sensu::Extension::NumOccurrences::STOP_PROCESSING
      )
      expect(subject.filter_by_num_occurrences(event).last).to match(
        /only handling every 60 /
      )
    end
  end

  context 'tests from "check filter_repeated" context in base_spec.rb' do
    context 'It should not fire before alert_after' do
      it do
        event = {
          check: {
            interval: 60,
            alert_after: 120,
            realert_every: 1
          },
          action: :create,
          occurrences: 1
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /Not failing long enough/
        )
      end
    end

    context 'It should not fire an alert after one alert_after period,
               because that would be the same as alert_after = 0' do
      it do
        event = {
          check: {
            interval: 60,
            alert_after: 60,
            realert_every: 100_000
          },
          occurrences: 1,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /Not failing long enough/
        )
      end
    end

    context 'It should fire an alert after it first reaches the alert_after,
               regardless of the realert_every' do
      it do
        event = {
          check: {
            interval: 60,
            alert_after: 120,
            realert_every: 100_000
          },
          occurrences: 3,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'It should fire an alert after the first check,
               even if alert_after == 0' do
      it do
        event = {
          check: {
            interval: 10,
            alert_after: 0,
            realert_every: 30
          },
          occurrences: 1,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'It should fire an event after the first check,
               if alert_after == 0 and realert_every 1' do
      it do
        event = {
          check: {
            interval: 10,
            alert_after: 0,
            realert_every: 1
          },
          occurrences: 1,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'interval 0 no divide by 0 error' do
      it do
        event = {
          check: {
            interval: 0
          },
          occurrences: 2,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, it should alert the first time' do
      it do
        event = {
          check: {
            interval: 20,
            realert_every: -1
          },
          occurrences: 1,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, it should alert the second time' do
      it do
        event = {
          check: {
            interval: 20,
            realert_every: -1
          },
          occurrences: 2,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, it should not alert the third time' do
      it do
        event = {
          check: {
            interval: 20,
            realert_every: -1
          },
          occurrences: 3,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /not on a power of two/
        )
      end
    end

    context 'When exponential backoff, it should alert the fourth time' do
      it do
        event = {
          check: {
            interval: 20,
            realert_every: -1
          },
          occurrences: 4,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, it should not alert the fifth time' do
      it do
        event = {
          check: {
            interval: 20,
            realert_every: -1
          },
          occurrences: 5,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /not on a power of two/
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should not alert the first time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 1,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /Not failing long enough/
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should not alert the second time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 2,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /Not failing long enough/
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should not alert the third time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 3,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /Not failing long enough/
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should alert the fourth time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 4,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should alert the fifth time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 5,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end

    context 'When exponential backoff, and alert_after,
               it should not alert the sixth time' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60,
            realert_every: -1
          },
          occurrences: 6,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::STOP_PROCESSING
        )
        expect(subject.filter_by_num_occurrences(event).last).to match(
          /not on a power of two/
        )
      end
    end

    context 'When realert_every is not set,
               it should treat realert_every as 1' do
      it do
        event = {
          check: {
            interval: 20,
            alert_after: 60
          },
          occurrences: 6,
          action: :create
        }
        expect(subject.filter_by_num_occurrences(event).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING
        )
      end
    end
  end
end

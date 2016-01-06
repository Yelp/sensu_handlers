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
        :check => {
          :interval => 60,
          :alert_after => 300,
        },
        :occurrences => 2
      }
      expect(subject.filter_by_num_occurrences(event).first).to eql(
        Sensu::Extension::NumOccurrences::STOP_PROCESSING)
      expect(subject.filter_by_num_occurrences(event).last).to match(
        /Not failing long enough/)
    end
  end

  context 'exponential backoff' do
    event = {
      :check => {
        :interval => 60,
        :alert_after => 300,
        :realert_every => -1,
      },
      :action => :create,
    }

    it 'when not on power of two, should return STOP_PROCESSING' do
      [ 15, 24 ].each do |i|
        expect(subject.filter_by_num_occurrences(
          event.merge(:occurrences => i)).first).to eql(
            Sensu::Extension::NumOccurrences::STOP_PROCESSING)
        expect(subject.filter_by_num_occurrences(
          event.merge(:occurrences => i)).last).to match(
            /not on a power of two/)
      end
    end

    it 'when on power of two, should return ALLOW_PROCESSING' do
      expect(subject.filter_by_num_occurrences(
        event.merge(:occurrences => 261)).first).to eql(
          Sensu::Extension::NumOccurrences::ALLOW_PROCESSING)
      expect(subject.filter_by_num_occurrences(
        event.merge(:occurrences => 261)).last).to match(
          /can be processed/)
    end
  end

  context 'with realert_every' do
    it 'should return STOP_PROCESSING' do
      event = {
        :check => {
          :interval => 60,
          :alert_after => 300,
          :realert_every => 60,
        },
        :action => :create,
        :occurrences => 99,
      }

      expect(subject.filter_by_num_occurrences(event).first).to eql(
        Sensu::Extension::NumOccurrences::STOP_PROCESSING)
      expect(subject.filter_by_num_occurrences(event).last).to match(
        /only handling every 60 /)
    end
  end

end

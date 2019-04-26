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

require "#{File.dirname(__FILE__)}/../../files/sensu_slo"

class SensuSLOHandler
  attr_accessor :settings
end

describe SensuSLOHandler do
  include SensuHandlerTestHelper

  let(:hostname) { 'Spec Host' }
  let(:metric_name) { 'Spec Metric' }
  let(:check_name) { 'Spec Check' }
  let(:client_name) { 'Spec Client' }
  let(:habitat) { 'Spec Habitat' }

  subject { SensuSLOHandler.new }
  before(:each) do
      setup_event! do |e|
        e['check']['name'] = check_name
        e['client']['name'] = client_name
      end
  end

  describe "create_dimensions_json" do
    let(:create_dimensions_json) { subject.create_dimensions_json }

    before(:each) do
      $hostname = hostname
      $metric_name = metric_name

      File.stub(:read) { habitat }
    end

    context "returns a correctly sorted dimensions json array" do
      specify { expect(create_dimensions_json).to eql "[[\"check_name\",\"#{check_name}\"],[\"client_name\",\"#{client_name}\"],[\"habitat\",\"#{habitat}\"],[\"hostname\",\"#{hostname}\"],[\"metric_name\",\"#{metric_name}\"]]" }
    end
  end

end


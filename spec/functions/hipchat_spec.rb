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
end

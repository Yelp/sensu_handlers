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

require "#{File.dirname(__FILE__)}/../../files/aws_prune"

class MockEc2Node < Ec2Node 
  attr_accessor :settings
  def load_instances_cache
    [
        {
            'id' => 'i-before',
            'tags' => { 'Name' => 'some.hostname' }
        },
        {
            'id' => 'i-blacklisted',
            'tags' => { 'Name' => 'xxx' }
        },
        {
            'id' => 'i-after',
            'tags' => { 'Name' => 'some.other.hostname' }
        },
	{
	    'id' => 'i-terminated',
	    'tags' => { 'Name' => 'a.dead.instance' },
	    'state' => 'terminated'
	}
    ]
  end
  def blacklist_name_array
    ['xxx']
  end
end

describe MockEc2Node do
  include SensuHandlerTestHelper

  subject { MockEc2Node.new }
  before(:each) { setup_event! }

  it "Cannot find instance which doesnt exist" do
    subject.ec2_node_exists?('i-doesnotexist').should == false
  end
  it "Can find i-before" do
    subject.ec2_node_exists?('i-before').should == true
  end
  it "Cannot find blacklisted instance" do
    subject.ec2_node_exists?('i-blacklisted').should == false
  end
  it "Can find instance after blacklist" do
    subject.ec2_node_exists?('i-after').should == true
  end
  it "Cannot find terminated instance" do
    subject.ec2_node_exists?('i-terminated').should == false
  end
end

describe Ec2Node do
    include SensuHandlerTestHelper
    subject { Ec2Node.new }

    it "Has sane defaults without config" do
      subject.blacklist_name_array.should == []
    end
end



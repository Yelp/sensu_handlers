require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

require "#{File.dirname(__FILE__)}/../../files/nodebot"

class Nodebot
  attr_accessor :settings
  attr_reader :sent
  def send(channel, message)
    @sent = [channel, message]
  end
end

describe Nodebot do
  include SensuHandlerTestHelper

  subject { Nodebot.new }
  before(:each) { setup_event! }

  context "Fails without providing a team" do
#    lambda {
#        cli_method(false)
#      }.should raise(SystemExit)
  end

  context "should page pages channel setup by team" do
    before(:each) do
      subject.event['check']['page'] = true
      subject.event['check']['team'] = 'operations'
      subject.settings[settings_key]['teams']['operations']['pages_irc_channel'] = '#criticals'
    end
    it { expect(subject.pages_irc_channel).to eql('#criticals') }
    it { expect(subject.channels).to eql(['criticals']) }
    timestamp_regex = / \(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\)$/
    it { expect(subject.message).to match(timestamp_regex) }
  end
  context "should page default team pages channel when not setup" do
    before(:each) do
      subject.event['check']['page'] = true 
      subject.event['check']['team'] = 'operations'
    end
    it { expect(subject.pages_irc_channel).to eql('#operations-pages') }
    it { expect(subject.channels).to eql(['operations-pages']) }
  end
  context "Notifications channel" do
    context "No default" do
      #it("Does not notify by default") { subject.channels.should == [] }
      it("Does notify if overridden in check - singular") do
        subject.event['check']['irc_channels'] = '#annoy-kwa'
        expect(subject.channels).to eql(['annoy-kwa'])
      end
      it("Does notify if overridden in check - plural") do
        subject.event['check']['irc_channels'] = ['#annoy-kwa', '#annoy-tdoran']
        expect(subject.channels).to eql([ 'annoy-kwa', 'annoy-tdoran'])
      end
    end
    context "With notifications channel set up" do
      before(:each) do
        subject.event['check']['team'] = 'operations'
        subject.settings[settings_key]['teams']['operations']['notifications_irc_channel'] = '#operations-notifications'
      end
      it("Notifies setup channel") { expect(subject.channels).to eql(['operations-notifications']) }
      it("Gets overridden by irc_channels in check") do
        subject.event['check']['irc_channels'] = '#annoy-kwa'
        expect(subject.channels).to eql(['annoy-kwa'])
      end
    end
  end
end

describe "ColorHandling" do
  # Check if things round trip without modification
  ansi_to_irc_colors("Roundtrip").should == "Roundtrip"
  # Check bold conversion
  ansi_to_irc_colors("\33[1mSome text").should == "\02Some text"
  # Check a single color
  ansi_to_irc_colors("\33[30mBlack").should == "\03" + "01Black"
  # bold + color
  ansi_to_irc_colors("\33[1mBold \33[30mBlack").should == "\02Bold " + "\03" + "01Black"
  # background color
  ansi_to_irc_colors("\33[30;47mBlack on White").should == "\03" + "01,00Black on White"
  # background without foreground
  ansi_to_irc_colors("\33[47mWhite Background").should == "\03" + "99,00White Background"
  # invalid escape sequence
  ansi_to_irc_colors("\33!mInvalid").should == "Invalid"
  # test reset
  ansi_to_irc_colors("\33[1mBold \33[0mNormal").should == "\02Bold " + "\x0f" + "Normal"
end

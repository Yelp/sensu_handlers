require 'spec_helper'
require "#{File.dirname(__FILE__)}/../../files/delete_terminated_ec2_clients"

RSpec.describe SensuApiConnector do

  describe 'API communication' do

    before :each do
      @http_mock = double('http', :open_timeout= => 2)
      expect(Net::HTTP).to receive(:new).and_return(@http_mock)

      @request_mock = double('http_request')
      expect(@request_mock).to receive(:basic_auth).with('', '')

      logger = Logger.new(STDOUT)
      logger.level = Logger::UNKNOWN
      @sensu_api = SensuApiConnector.new('192.168.1.1', 80, '', '', logger)
    end

    it 'get_clients_with_instance_id should send a valid GET request and return hash' do
      expect(Net::HTTP::Get).to \
        receive(:new).with(URI('http://192.168.1.1/clients')).and_return(@request_mock)
      expect(@http_mock).to \
        receive(:request).with(@request_mock).and_return(
        double('response', :code => '200', :body => '[{"instance_id":"id-1", "name":"host1"}, {"name":"host2"}]'))
      expect(@sensu_api.get_clients_with_instance_id).to eq({'id-1' => 'host1'})
    end

    it 'get_clients_with_instance_id should return nul when HTTP response code is not 200' do
      expect(Net::HTTP::Get).to \
        receive(:new).with(URI('http://192.168.1.1/clients')).and_return(@request_mock)
      expect(@http_mock).to \
        receive(:request).with(@request_mock).and_return(
        double('response', :code => '401', :message => 'Unauthorized', :body => ''))
      expect(@sensu_api.get_clients_with_instance_id).to eq(nil)
    end

    it 'delete_client should send a valid Delete request' do
      expect(Net::HTTP::Delete).to \
        receive(:new).with(URI('http://192.168.1.1/clients/host1')).and_return(@request_mock)
      expect(@http_mock).to \
        receive(:request).with(@request_mock).and_return(
        double('response', :code => '202'))
      @sensu_api.delete_client('host1')
    end
  end

end


RSpec.describe AwsApiConnector do

  describe '#get_ec2_instances_info' do

    before :each do
      # stub every call to AWS API: https://ruby.awsblog.com/post/Tx15V81MLPR8D73/Client-Response-Stubs
      Aws.config[:stub_responses] = true
    end

    it 'should get info about EC2 resources and return hash' do
      @aws_api = AwsApiConnector.new('', '', '')
      @ec2_mock = double('ec2')
      @instance_mock = double('instance', :id => 'id-1', :state => {'name' =>'running'}, :tags => nil)
      expect(Aws::EC2::Resource).to receive(:new).and_return(@ec2_mock)
      expect(@ec2_mock).to receive(:instances).and_return([@instance_mock])
      expect(@aws_api.get_ec2_instanses_info).to eq({"id-1"=>{"state"=>"running", "tags"=>nil}})
    end
  end

end


RSpec.describe DeleteTerminatedEc2Clients do

  describe '#main' do

    before :each do
      # stub every call to AWS API: https://ruby.awsblog.com/post/Tx15V81MLPR8D73/Client-Response-Stubs
      Aws.config[:stub_responses] = true

      @sensu_mock = double('sensu', :get_clients_with_instance_id => {
                            'id-1' => 'host1',
                            'id-2' => 'host2',
                            'id-3' => 'host3',
                            'id-6' => 'host6',
                          })
      @ec2_mock = double('ec2', :get_ec2_instanses_info => {
                            'id-1' => {'state' => 'running'},
                            'id-2' => {'state' => 'terminated'},
                            'id-3' => {'state' => 'terminated'},
                            'id-4' => {'state' => 'running'},
                            'id-5' => {'state' => 'terminated'},
                         })
    end

    it 'should work properly' do
      job = DeleteTerminatedEc2Clients.new('fake', Logger::UNKNOWN, false)
      job.instance_variable_set('@sensu', @sensu_mock)
      job.instance_variable_set('@aws', @ec2_mock)
      expect(@sensu_mock).to receive(:delete_client).once.with('host2')
      expect(@sensu_mock).to receive(:delete_client).once.with('host3')
      expect(@sensu_mock).to receive(:delete_client).once.with('host6')

      expect(job._run).to eq(0)
    end

    it 'should not delete sensu clients in the noop mode' do
      job = DeleteTerminatedEc2Clients.new('fake', Logger::UNKNOWN, true)
      job.instance_variable_set('@sensu', @sensu_mock)
      job.instance_variable_set('@aws', @ec2_mock)
      expect(@sensu_mock).to receive(:delete_client).exactly(0).times
      expect(job._run).to eq(0)
    end

    it 'should not delete all sensu aws clients' do
      @ec2_mock = double('ec2', :get_ec2_instanses_info => {})
      job = DeleteTerminatedEc2Clients.new('fake', Logger::UNKNOWN, false)
      job.instance_variable_set('@sensu', @sensu_mock)
      job.instance_variable_set('@aws', @ec2_mock)
      expect(@sensu_mock).to receive(:delete_client).exactly(0).times
      expect(job._run).to eq(1)
    end

    it 'should return 0 when there is nothing to delete' do
      @sensu_mock = double('sensu', :get_clients_with_instance_id => {'id-1' => 'host1', 'id-4' => 'host4',})
      job = DeleteTerminatedEc2Clients.new('fake', Logger::UNKNOWN, false)
      job.instance_variable_set('@sensu', @sensu_mock)
      job.instance_variable_set('@aws', @ec2_mock)
      expect(@sensu_mock).to receive(:delete_client).exactly(0).times
      expect(job._run).to eq(0)
    end

  end

end

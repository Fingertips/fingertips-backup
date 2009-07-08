require File.expand_path('../test_helper', __FILE__)
require "ec2"

describe "Fingertips::EC2, in general" do
  before do
    @ami = 'ami-nonexistant'
    @instance = Fingertips::EC2.new
  end
  
  it "should return the right env variables to be able to use the Amazon CLI tools" do
    Fingertips::EC2::ENV.should == {
      'EC2_HOME'        => '/opt/ec2',
      'EC2_PRIVATE_KEY' => Fingertips::EC2::PRIVATE_KEY_FILE,
      'EC2_CERT'        => Fingertips::EC2::CERTIFICATE_FILE
    }
  end
  
  it "should return an array of lines splitted at tabs" do
    @instance.send(:parse, "    line1item1\tline1item2\nline2item1\tline2item2   ").should ==
      [['line1item1', 'line1item2'], ['line2item1', 'line2item2']]
  end
  
  it "should override #execute so it returns the response parsed" do
    @instance.send(:execute, 'ls').should == @instance.send(:parse, `ls`)
  end
end

describe "Fingertips::EC2, concerning the pre-defined commands" do
  before do
    @instance = Fingertips::EC2.new
    @options = { :switch_stdout_and_stderr => false, :env => Fingertips::EC2::ENV }
  end
  
  it "should run an instance of the given AMI with the given options and return the instance ID" do
    expect_call('run-instances', "ami-nonexistant -k fingertips")
    @instance.run_instance('ami-nonexistant', :k => 'fingertips').should == 'i-0992a760'
  end
  
  it "should return the status of an instance" do
    expect_call('describe-instances', 'i-nonexistant')
    @instance.describe_instance("i-nonexistant").should == "running"
  end
  
  it "should terminate an instance" do
    expect_call('terminate-instances', 'i-nonexistant')
    @instance.terminate_instance('i-nonexistant').should == "shutting-down"
  end
  
  it "should return if an instance is running" do
    expect_call('describe-instances', 'i-nonexistant')
    @instance.running?('i-nonexistant').should.be true
  end
  
  private
  
  def expect_call(name, args)
    @instance.expects(:execute).with("/opt/ec2/bin/ec2-#{name} #{args}", @options).returns(@instance.send(:parse, fixture_read(name)))
  end
end
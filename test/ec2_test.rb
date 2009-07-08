require File.expand_path('../test_helper', __FILE__)
require "ec2"

describe "Fingertips::EC2, in general" do
  before do
    @ami = 'ami-0d729464'
    @instance = Fingertips::EC2.new(@ami)
  end
  
  it "should start an instance with the given AMI" do
    Fingertips::EC2.expects(:new).with(@ami).returns(@instance)
    @instance.expects(:launch!)
    Fingertips::EC2.launch(@ami).should.be @instance
  end
  
  it "should return the command to execute to set the right env" do
    Fingertips::EC2::ENV.should == "/usr/bin/env EC2_HOME='/opt/ec2' EC2_PRIVATE_KEY='#{Fingertips::EC2::PRIVATE_KEY_FILE}' EC2_CERT='#{Fingertips::EC2::CERTIFICATE_FILE}'"
  end
  
  it "should initialize with an AMI" do
    @instance.ami.should == @ami
  end
  
  it "should return an array of lines splitted at tabs" do
    @instance.send(:parse, "    line1item1\tline1item2\nline2item1\tline2item2   ").should ==
      [['line1item1', 'line1item2'], ['line2item1', 'line2item2']]
  end
  
  it "should execute an EC2 cli command" do
    response = fixture_read('describe-images')
    @instance.expects(:`).with("#{Fingertips::EC2::ENV} /opt/ec2/bin/ec2-describe-images -o amazon").returns(response)
    @instance.send(:execute, 'describe-images', '-o', 'amazon').should == @instance.send(:parse, response)
  end
end

describe "Fingertips::EC2, concerning the pre-defined commands" do
  before do
    @ami = 'ami-0d729464'
    @instance = Fingertips::EC2.new(@ami)
  end
  
  it "should run an instance with the given options and return the instance ID" do
    expect_call('run-instances', @ami, '-k', 'fingertips')
    @instance.run_instances(:k => 'fingertips').should == 'i-0992a760'
  end
  
  private
  
  def expect_call(name, *args)
    @instance.expects(:execute).with(name, *args).returns(@instance.send(:parse, fixture_read(name)))
  end
end
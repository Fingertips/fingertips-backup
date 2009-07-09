require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::EC2, in general" do
  before do
    @ami = 'ami-nonexistant'
    @instance = Fingertips::EC2.new('/path/to/private_key_file', '/path/to/certificate_file')
  end
  
  it "should return the right env variables to be able to use the Amazon CLI tools" do
    @instance.env.should == {
      'EC2_HOME'        => '/opt/ec2',
      'EC2_PRIVATE_KEY' => '/path/to/private_key_file',
      'EC2_CERT'        => '/path/to/certificate_file'
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
    @instance = Fingertips::EC2.new('/path/to/private_key_file', '/path/to/certificate_file')
    @options = { :switch_stdout_and_stderr => false, :env => @instance.env }
  end
  
  it "should run an instance of the given AMI with the given options and return the instance ID" do
    expect_call('run-instances', "ami-nonexistant -k fingertips")
    @instance.run_instance('ami-nonexistant', :k => 'fingertips').should == 'i-0992a760'
  end
  
  it "should return the status of an instance" do
    expect_call('describe-instances', 'i-nonexistant')
    @instance.describe_instance("i-nonexistant").should == @instance.send(:parse, fixture_read('describe-instances'))[1]
  end
  
  it "should terminate an instance" do
    expect_call('terminate-instances', 'i-nonexistant')
    @instance.terminate_instance('i-nonexistant').should == 'shutting-down'
  end
  
  it "should return if an instance is running" do
    expect_call('describe-instances', 'i-nonexistant')
    @instance.running?('i-nonexistant').should.be true
  end
  
  it "should return the public host address of an instance" do
    expect_call('describe-instances', 'i-nonexistant')
    @instance.host_of_instance('i-nonexistant').should == 'ec2-174-129-88-205.compute-1.amazonaws.com'
  end
  
  it "should attach an EBS volume to an EC2 instance" do
    expect_call('attach-volume', 'vol-nonexistant -i i-nonexistant -d /dev/sdh')
    @instance.attach_volume('vol-nonexistant', 'i-nonexistant', :d => '/dev/sdh')
  end
  
  it "should return the status of a volume" do
    expect_call('describe-volumes', 'vol-nonexistant')
    @instance.describe_volume('vol-nonexistant').should == @instance.send(:parse, fixture_read('describe-volumes'))[1]
  end
  
  it "should return if a volume is attached" do
    expect_call('describe-volumes', 'vol-nonexistant')
    @instance.attached?('vol-nonexistant').should.be true
  end
  
  private
  
  def expect_call(name, args)
    @instance.expects(:execute).with("/opt/ec2/bin/ec2-#{name} #{args}", @options).returns(@instance.send(:parse, fixture_read(name)))
  end
end
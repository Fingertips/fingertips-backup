require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::Backup, in general" do
  before do
    @config = YAML.load(fixture_read('config.yml'))
    @backup = Fingertips::Backup.new(fixture('config.yml'))
  end
  
  it "should return the config" do
    @backup.config.should == @config
  end
  
  it "should return a list of all MySQL databases" do
    databases = @backup.mysql_databases
    databases.should.include 'information_schema'
    databases.should == `mysql --batch --skip-column-names -e "show databases"`.strip.split("\n")
  end
  
  it "should return a configured Fingertips::EC2 instance" do
    @backup.ec2.should.be.instance_of Fingertips::EC2
    @backup.ec2.private_key_file.should == @config['ec2']['private_key_file']
    @backup.ec2.certificate_file.should == @config['ec2']['certificate_file']
  end
end

describe "Fingertips::Backup, concerning the MySQL backup" do
  before do
    @backup = Fingertips::Backup.new(fixture('config.yml'))
    @backup.stubs(:mysql_databases).returns(%w{ information_schema })
  end
  
  after do
    FileUtils.rm_rf(@backup.tmp_path)
  end
  
  it "should return the tmp mysql dump dir" do
    @backup.mysql_dump_dir.should == File.join(@backup.tmp_path, 'mysql')
  end
  
  it "should create the tmp mysql dump dir" do
    @backup.create_mysql_dump
    File.should.exist @backup.mysql_dump_dir
    File.should.be.directory @backup.mysql_dump_dir
  end
  
  it "should dump each database into its own file" do
    @backup.create_mysql_dump
    
    actual = strip_comments(`mysqldump information_schema --add-drop-table`)
    dump = strip_comments(File.read(File.join(@backup.mysql_dump_dir, 'information_schema.sql')))
    
    actual.should == dump
  end
  
  private
  
  def strip_comments(sql)
    sql.gsub(/^--.*?$/, '').strip
  end
end

describe "Fingertips::Backup, concerning syncing with EBS" do
  before do
    @backup = Fingertips::Backup.new(fixture('config.yml'))
    @ec2 = @backup.ec2
    
    @ec2.stubs(:run_instance).returns("i-nonexistant")
    @ec2.stubs(:running?).returns(true)
    
    @ec2.stubs(:attach_volume)
    @ec2.stubs(:attached?).returns(true)
  end
  
  it "should run an EC2 instance and wait till it's online" do
    @backup.stubs(:mount_backup_volume!)
    
    @ec2.expects(:run_instance).with('ami-nonexistant', :k => 'fingertips', :z => 'eu-west-1a').returns("i-nonexistant")
    
    @ec2.expects(:running?).with do |id|
      # next time it's queried it will be running
      def @ec2.running?(id)
        true
      end
      
      id == "i-nonexistant"
    end.returns(false)
    
    @backup.bring_backup_volume_online!
    @backup.ec2_instance_id.should == "i-nonexistant"
  end
  
  it "should attach the existing EBS instance and wait till it's online" do
    @backup.stubs(:mount_backup_volume!)
    
    @ec2.expects(:attach_volume).with("vol-nonexistant", "i-nonexistant", :d => "/dev/sdh")
    
    @ec2.expects(:attached?).with do |id|
      # next time it's queried it will be attached
      def @ec2.attached?(id)
        true
      end
      
      id == "vol-nonexistant"
    end.returns(false)
    
    @backup.bring_backup_volume_online!
  end
  
  it "should mount the attached EBS volume on the running instance" do
    @ec2.expects(:host_of_instance).with('i-nonexistant').returns('instance.amazon.com')
    
    ssh = mock('Net::SSH')
    Net::SSH.expects(:start).with('instance.amazon.com', 'root', :keys => [@backup.config['ec2']['keypair_file']]).yields(ssh)
    ssh.expects(:exec!).with('mkdir /mnt/data-store')
    ssh.expects(:exec!).with('mount /dev/sdh /mnt/data-store')
    
    @backup.bring_backup_volume_online!
  end
end
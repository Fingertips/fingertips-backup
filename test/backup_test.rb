require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::Backup, in general" do
  before do
    @config = YAML.load(fixture_read('config.yml'))
    @backup = Fingertips::Backup.new(fixture('config.yml'))
  end
  
  it "should have instantiated a Logger and assigned it to Executioner" do
    @backup.logger.should.be.instance_of Fingertips::Logger
    Executioner.logger.should.be @backup.logger
  end
  
  it "should return the config" do
    @backup.config.should == @config
  end
  
  it "should return a configured Fingertips::EC2 instance" do
    @backup.ec2.should.be.instance_of Fingertips::EC2
    @backup.ec2.zone.should == @config['ec2']['zone']
    @backup.ec2.private_key_file.should == @config['ec2']['private_key_file']
    @backup.ec2.certificate_file.should == @config['ec2']['certificate_file']
  end
  
  it "should return a list of all MySQL databases" do
    databases = @backup.mysql_databases
    databases.should.include 'information_schema'
    databases.should == `mysql -u root --batch --skip-column-names -e "show databases"`.strip.split("\n")
  end
  
  it "should return the host of the EC2 instance" do
    @backup.ec2_instance_id = 'i-nonexistant'
    @backup.ec2.expects(:host_of_instance).with('i-nonexistant').returns('instance.amazon.com')
    @backup.ec2_host.should == 'instance.amazon.com'
  end
  
  it "should perform a full run and report that the backup finished" do
    @backup.expects(:create_mysql_dump!)
    @backup.expects(:bring_backup_volume_online!)
    @backup.ec2_instance_id = 'i-nonexistant'
    @backup.expects(:sync!)
    @backup.expects(:take_backup_volume_offline!)
    @backup.expects(:finished)
    
    @backup.run!
  end
  
  it "should catch any type of exception that was raised during initialization and call #failed" do
    Fingertips::Backup.any_instance.expects(:failed).with { |exception| exception.backtrace.to_s.include?('initialize') }
    backup = Fingertips::Backup.new(nil)
  end
  
  it "should catch any type of exception that was raised during the run and terminate the EC2 instance if one was launched and call #failed" do
    @backup.stubs(:finished)
    
    @backup.ec2_instance_id = 'i-nonexistant'
    @backup.stubs(:create_mysql_dump!).raises 'oh noes!'
    @backup.expects(:failed).with { |exception| exception.message == 'oh noes!' }
    @backup.expects(:take_backup_volume_offline!)
    @backup.run!
  end
  
  it "should report that the backup failed and re-raise the exception" do
    exception = nil
    begin; raise 'oh noes!'; rescue Exception => e; exception = e; end
    
    @backup.expects(:write_feed!)
    lambda { @backup.failed(exception) }.should.raise exception.class
    @backup.logger.logged.first.should.include 'oh noes!'
    @backup.logger.logged.last.should == "[!] The backup has failed."
  end
  
  it "should report that the backup has finished" do
    @backup.expects(:write_feed!)
    @backup.finished
    @backup.logger.logged.last.should == "The backup finished."
  end
  
  it "should write the feed of the current log" do
    @backup.logger.expects(:write_feed).with(@config['log_feed'])
    @backup.write_feed!
  end
end

describe "Fingertips::Backup, concerning the MySQL backup" do
  before do
    @backup = Fingertips::Backup.new(fixture('config.yml'))
    @backup.stubs(:mysql_databases).returns(%w{ information_schema })
  end
  
  after do
    FileUtils.rm_rf(Fingertips::Backup::MYSQL_DUMP_DIR)
  end
  
  it "should first remove the tmp mysql dump dir" do
    # have to use at_least_once because it's also called in the after filter
    FileUtils.expects(:rm_rf).with(Fingertips::Backup::MYSQL_DUMP_DIR).at_least_once
    @backup.create_mysql_dump!
  end
  
  it "should create the tmp mysql dump dir" do
    @backup.create_mysql_dump!
    File.should.exist Fingertips::Backup::MYSQL_DUMP_DIR
    File.should.be.directory Fingertips::Backup::MYSQL_DUMP_DIR
  end
  
  it "should dump each database into its own file" do
    @backup.create_mysql_dump!
    
    actual = strip_comments(`mysqldump -u root information_schema --add-drop-table`)
    dump = strip_comments(File.read(File.join(Fingertips::Backup::MYSQL_DUMP_DIR, 'information_schema.sql')))
    
    actual.should == dump
  end
  
  private
  
  def strip_comments(sql)
    sql.gsub(/^--.*?$/, '').strip
  end
end

describe "Fingertips::Backup, concerning the EBS volume" do
  before do
    @backup = Fingertips::Backup.new(fixture('config.yml'))
    @config = @backup.config
    @ec2 = @backup.ec2
    
    @backup.stubs(:sleep)
    
    @ec2.stubs(:run_instance).returns("i-nonexistant")
    @ec2.stubs(:running?).returns(true)
    
    @ec2.stubs(:attach_volume)
    @ec2.stubs(:attached?).returns(true)
  end
  
  it "should run an EC2 instance and wait till it's online" do
    @backup.stubs(:mount_backup_volume!)
    
    @ec2.expects(:run_instance).with('ami-nonexistant', 'fingertips').returns("i-nonexistant")
    
    @ec2.expects(:running?).with do |id|
      # next time it's queried it will be running
      def @ec2.running?(id)
        true
      end
      
      id == "i-nonexistant"
    end.returns(false)
    @backup.expects(:sleep).with(5).once
    
    @backup.launch_ec2_instance!
    @backup.ec2_instance_id.should == "i-nonexistant"
  end
  
  it "should attach the existing EBS instance and wait till it's online" do
    @backup.ec2_instance_id = 'i-nonexistant'
    @ec2.expects(:attach_volume).with("vol-nonexistant", "i-nonexistant", "/dev/sdh")
    
    @ec2.expects(:attached?).with do |id|
      # next time it's queried it will be attached
      def @ec2.attached?(id)
        true
      end
      
      id == "vol-nonexistant"
    end.returns(false)
    @backup.expects(:sleep).with(2.5).once
    
    @backup.attach_backup_volume!
  end
  
  it "should mount the attached EBS volume on the running instance" do
    @backup.stubs(:ec2_host).returns('instance.amazon.com')
    @backup.expects(:ssh).with("-o 'StrictHostKeyChecking=no' -i '#{@config['ec2']['keypair_file']}' root@instance.amazon.com 'mkdir /mnt/data-store && mount /dev/sdh /mnt/data-store'")
    @backup.mount_backup_volume!
  end
  
  it "should run all steps to bring the backup volume online" do
    @backup.expects(:launch_ec2_instance!)
    @backup.expects(:attach_backup_volume!)
    @backup.expects(:mount_backup_volume!)
    
    @backup.bring_backup_volume_online!
  end
  
  it "should take the backup volume offline by terminating the EC2 instance" do
    @backup.ec2_instance_id = 'i-nonexistant'
    @backup.ec2.expects(:terminate_instance).with('i-nonexistant')
    @backup.take_backup_volume_offline!
  end
end

describe "Fingertips::Backup, concerning syncing" do
  before do
    @backup = Fingertips::Backup.new(fixture('config.yml'))
    @backup.stubs(:ec2_host).returns('instance.amazon.com')
  end
  
  it "should sync all configured paths and the mysql dump dir to the backup volume" do
    @backup.expects(:rsync).with("-avz -e \"ssh -i '#{@backup.config['ec2']['keypair_file']}'\" '#{Fingertips::Backup::MYSQL_DUMP_DIR}' '/var/www/apps' '/root' root@instance.amazon.com:/mnt/data-store")
    @backup.sync!
  end
end
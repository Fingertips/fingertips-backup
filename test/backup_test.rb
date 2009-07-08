require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::Backup, in general" do
  before do
    @config = YAML.load(fixture_read('config.yml'))
    @backup = Fingertips::Backup.new(fixture('config.yml'))
  end
  
  it "should return the EC2 config" do
    @backup.ec2_config.should == @config['ec2']
  end
  
  it "should return the paths to backup" do
    @backup.paths.should == @config['backup']['paths']
  end
  
  it "should return the path to the tmp backup dirs" do
    @backup.tmp_path.should == '/tmp/ec2_test_backup'
  end
  
  it "should return a list of all MySQL databases" do
    databases = @backup.mysql_databases
    databases.should.include 'information_schema'
    databases.should == `mysql --batch --skip-column-names -e "show databases"`.strip.split("\n")
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
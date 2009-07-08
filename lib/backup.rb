require "rubygems"
require "executioner"
require "yaml"

require "ec2"

module Fingertips
  class Backup
    include Executioner
    Executioner::SEARCH_PATHS << '/usr/local/mysql/bin'
    executable :mysql
    executable :mysqldump
    
    attr_reader :paths, :tmp_path
    attr_reader :ami, :ec2, :ec2_instance_id
    
    def initialize(config_file)
      config = YAML.load(File.read(config_file))
      
      @tmp_path = config['backup']['tmp']
      @paths    = config['backup']['paths']
      @ami      = config['ec2']['ami']
      @ec2      = Fingertips::EC2.new(config['ec2']['private_key_file'], config['ec2']['certificate_file'])
    end
    
    def bring_backup_volume_online!
      @ec2_instance_id = @ec2.run_instance(@ami)
      sleep 2.5 until @ec2.running?(@ec2_instance_id)
    end
    
    def mysql_databases
      @mysql_databases ||= mysql('--batch --skip-column-names -e "show databases"').strip.split("\n")
    end
    
    def mysql_dump_dir
      File.join(@tmp_path, 'mysql')
    end
    
    def create_mysql_dump
      FileUtils.mkdir_p(mysql_dump_dir)
      
      mysql_databases.each do |database|
        mysqldump("#{database} --add-drop-table > '#{File.join(mysql_dump_dir, database)}.sql'")
      end
    end
  end
end
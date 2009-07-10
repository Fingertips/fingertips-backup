require "yaml"

require "rubygems"
require "executioner"

gem 'net-ssh', '~> 2.0.11'
require "net/ssh"

require "ec2"

module Fingertips
  class Backup
    include Executioner
    Executioner::SEARCH_PATHS << '/usr/local/mysql/bin'
    executable :mysql
    executable :mysqldump
    
    attr_reader :config, :ec2
    attr_accessor :ec2_instance_id
    
    def initialize(config_file)
      @config = YAML.load(File.read(config_file))
      @ec2    = Fingertips::EC2.new(@config['ec2']['zone'], @config['ec2']['private_key_file'], @config['ec2']['certificate_file'], @config['java_home'])
    end
    
    def tmp_path
      @config['backup']['tmp']
    end
    
    def bring_backup_volume_online!
      launch_ec2_instance!
      attach_backup_volume!
      mount_backup_volume!
    end
    
    def launch_ec2_instance!
      @ec2_instance_id = @ec2.run_instance(@config['ec2']['ami'], @config['ec2']['keypair_name'])
      sleep 2.5 until @ec2.running?(@ec2_instance_id)
    end
    
    def attach_backup_volume!
      @ec2.attach_volume(@config['ec2']['ebs'], ec2_instance_id, "/dev/sdh")
      sleep 2.5 until @ec2.attached?(@config['ec2']['ebs'])
    end
    
    def mount_backup_volume!
      Net::SSH.start(@ec2.host_of_instance(ec2_instance_id), 'root', :auth_methods => %w{ publickey }, :keys => [@config['ec2']['keypair_file']], :verbose => :info) do |ssh|
        ssh.exec! 'mkdir /mnt/data-store'
        ssh.exec! 'mount /dev/sdh /mnt/data-store'
      end
    end
    
    def mysql_databases
      @mysql_databases ||= mysql('-u root --batch --skip-column-names -e "show databases"').strip.split("\n")
    end
    
    def mysql_dump_dir
      File.join(tmp_path, 'mysql')
    end
    
    def create_mysql_dump
      FileUtils.mkdir_p(mysql_dump_dir)
      
      mysql_databases.each do |database|
        mysqldump("-u root #{database} --add-drop-table > '#{File.join(mysql_dump_dir, database)}.sql'")
      end
    end
  end
end
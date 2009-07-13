require "yaml"

require "rubygems"
require "executioner"
require "aws/s3"

require "logger"
require "ec2"

module Fingertips
  class Backup
    include Executioner
    Executioner::SEARCH_PATHS << '/usr/local/mysql/bin'
    executable :mysql
    executable :mysqldump
    executable :rsync
    executable :ssh, :switch_stdout_and_stderr => true
    
    MYSQL_DUMP_DIR = '/tmp/mysql_backup_dumps'
    
    attr_reader :config, :ec2, :logger, :s3
    attr_accessor :ec2_instance_id
    
    def initialize(config_file)
      @logger = Executioner.logger = Fingertips::Logger.new
      @config = YAML.load(File.read(config_file))
      @ec2    = Fingertips::EC2.new(@config['ec2']['zone'], @config['ec2']['private_key_file'], @config['ec2']['certificate_file'], @config['java_home'])
      @s3     = AWS::S3::Base.establish_connection!(:access_key_id => @config['s3']['access_key_id'], :secret_access_key => @config['s3']['secret_access_key'])
    rescue Exception => e
      failed(e)
    end
    
    def finished
      @logger.debug "The backup finished."
      publish_log!
    end
    
    def failed(exception)
      @logger.debug "#{exception.message} #{exception.backtrace.join("\n")}"
      @logger.debug "[!] The backup has failed."
      publish_log!
      raise exception
    end
    
    def write_feed!
      @logger.write_feed(@config['log_feed'])
    end
    
    def publish_log!
      write_feed!
      AWS::S3::S3Object.store('backup_feed.xml', File.open(@config['log_feed']), @config['s3']['bucket'], :content_type => 'application/atom+xml', :access => :public_read)
    end
    
    def run!
      begin
        create_mysql_dump!
        bring_backup_volume_online!
        sync!
      rescue Exception => e
        failed(e)
      ensure
        take_backup_volume_offline! if ec2_instance_id
      end
      finished
    end
    
    def bring_backup_volume_online!
      launch_ec2_instance!
      attach_backup_volume!
      mount_backup_volume!
    end
    
    def launch_ec2_instance!
      @ec2_instance_id = @ec2.run_instance(@config['ec2']['ami'], @config['ec2']['keypair_name'])
      sleep 5 until @ec2.running?(@ec2_instance_id)
    end
    
    def attach_backup_volume!
      @ec2.attach_volume(@config['ec2']['ebs'], ec2_instance_id, "/dev/sdh")
      sleep 2.5 until @ec2.attached?(@config['ec2']['ebs'])
    end
    
    def mount_backup_volume!
      ssh "-o 'StrictHostKeyChecking=no' -i '#{@config['ec2']['keypair_file']}' root@#{ec2_host} 'mkdir /mnt/data-store && mount /dev/sdh /mnt/data-store'"
    end
    
    def take_backup_volume_offline!
      @ec2.terminate_instance @ec2_instance_id
    end
    
    def ec2_host
      @ec2_host ||= @ec2.host_of_instance(ec2_instance_id)
    end
    
    def mysql_databases
      @mysql_databases ||= mysql('-u root --batch --skip-column-names -e "show databases"').strip.split("\n")
    end
    
    def create_mysql_dump!
      FileUtils.rm_rf(MYSQL_DUMP_DIR)
      FileUtils.mkdir_p(MYSQL_DUMP_DIR)
      
      mysql_databases.each do |database|
        mysqldump("-u root #{database} --add-drop-table > '#{File.join(MYSQL_DUMP_DIR, database)}.sql'")
      end
    end
    
    def sync!
      rsync "-avz -e \"ssh -i '#{@config['ec2']['keypair_file']}'\" '#{MYSQL_DUMP_DIR}' '#{@config['backup'].join("' '")}' root@#{ec2_host}:/mnt/data-store"
    end
  end
end
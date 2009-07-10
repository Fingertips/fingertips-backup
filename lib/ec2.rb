require "rubygems"
require "executioner"

module Fingertips
  class EC2
    PRIVATE_KEY_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/pk-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    CERTIFICATE_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/cert-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    
    HOME = '/opt/ec2'
    BIN = File.join(HOME, 'bin')
    
    include Executioner
    Executioner::SEARCH_PATHS << BIN
    
    attr_reader :zone, :private_key_file, :certificate_file, :java_home
    
    def initialize(zone, private_key_file, certificate_file, java_home)
      @zone, @private_key_file, @certificate_file, @java_home = zone, private_key_file, certificate_file, java_home
    end
    
    def env
      @env ||= {
        'JAVA_HOME'       => @java_home,
        'EC2_HOME'        => HOME,
        'EC2_PRIVATE_KEY' => @private_key_file,
        'EC2_CERT'        => @certificate_file,
        'EC2_URL'         => "https://#{@zone[0..-2]}.ec2.amazonaws.com"
      }
    end
    
    # EC2
    
    def run_instance(ami, keypair_name, options = {})
      ec2_run_instances("#{ami} -z #{@zone} -k #{keypair_name}", :env => env)[1][1]
    end
    
    def describe_instance(instance_id)
      ec2_describe_instances(instance_id, :env => env).detect { |line| line[1] == instance_id }
    end
    
    def terminate_instance(instance_id)
      ec2_terminate_instances(instance_id, :env => env)[0][3]
    end
    
    def running?(instance_id)
      describe_instance(instance_id)[5] == 'running'
    end
    
    def host_of_instance(instance_id)
      describe_instance(instance_id)[3]
    end
    
    # EBS
    
    def attach_volume(volume_id, instance_id, device)
      ec2_attach_volume("#{volume_id} -i #{instance_id} -d #{device}", :env => env)
    end
    
    def describe_volume(volume_id)
      ec2_describe_volumes(volume_id, :env => env).detect { |line| line[0] == 'ATTACHMENT' && line[1] == volume_id }
    end
    
    def attached?(volume_id)
      describe_volume(volume_id)[4] == 'attached'
    end
    
    private
    
    executable 'ec2-run-instances'
    executable 'ec2-describe-instances'
    executable 'ec2-terminate-instances'
    
    executable 'ec2-attach-volume'
    executable 'ec2-describe-volumes'
    
    def parse(text)
      text.strip.split("\n").map { |line| line.split("\t") }
    end
    
    def execute(command, options = {})
      parse(super)
    end
  end
end
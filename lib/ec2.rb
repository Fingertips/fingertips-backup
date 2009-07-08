require "rubygems"
require "executioner"

module Fingertips
  class EC2
    PRIVATE_KEY_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/pk-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    CERTIFICATE_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/cert-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    
    HOME = '/opt/ec2'
    BIN = File.join(HOME, 'bin')
    
    ENV = { 'EC2_HOME' => HOME, 'EC2_PRIVATE_KEY' => PRIVATE_KEY_FILE, 'EC2_CERT' => CERTIFICATE_FILE }
    
    include Executioner
    Executioner::SEARCH_PATHS << BIN
    
    def run_instance(ami, options = {})
      ec2_run_instances("#{ami} #{concat_args(options)}")[1][1]
    end
    
    def describe_instance(instance_id)
      ec2_describe_instances(instance_id).detect { |line| line[1] == instance_id }[5]
    end
    
    def terminate_instance(instance_id)
      ec2_terminate_instances(instance_id)[0][3]
    end
    
    def running?(instance_id)
      describe_instance(instance_id) == "running"
    end
    
    private
    
    executable 'ec2-run-instances',       :env => ENV
    executable 'ec2-describe-instances',  :env => ENV
    executable 'ec2-terminate-instances', :env => ENV
    
    def parse(text)
      text.strip.split("\n").map { |line| line.split("\t") }
    end
    
    def execute(command, options = {})
      parse(super)
    end
  end
end
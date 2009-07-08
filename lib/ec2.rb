module Fingertips
  class EC2
    PRIVATE_KEY_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/pk-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    CERTIFICATE_FILE = '/Volumes/Fingertips Confidential/aws/fingertips/cert-6LN7EWTYKIDRU25OJYMTY6P75S43WA45.pem'
    
    HOME = '/opt/ec2'
    BIN = File.join(HOME, 'bin', 'ec2-%s')
    
    ENV = "/usr/bin/env EC2_HOME='#{HOME}' EC2_PRIVATE_KEY='#{PRIVATE_KEY_FILE}' EC2_CERT='#{CERTIFICATE_FILE}'"
    
    def self.launch(ami)
      instance = new(ami)
      instance.launch!
      instance
    end
    
    attr_reader :ami
    
    def initialize(ami)
      @ami = ami
    end
    
    def run_instances(options = {})
      response = execute('run-instances', @ami, *options.map { |k,v| ["-#{k}", v] }.flatten)
      response[1][1]
    end
    
    private
    
    def parse(text)
      text.strip.split("\n").map { |line| line.split("\t") }
    end
    
    def execute(command, *args)
      parse(`#{ENV} #{BIN % command} #{args.join(' ')}`)
    end
  end
end
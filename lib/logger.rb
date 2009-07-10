module Fingertips
  class Logger
    attr_reader :logged
    
    def initialize
      @logged = []
    end
    
    def debug(message)
      @logged << message
    end
  end
end
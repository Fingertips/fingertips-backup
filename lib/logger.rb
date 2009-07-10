require "builder"
require "rss"

module Fingertips
  class Logger
    class << self
      attr_accessor :print
    end
    self.print = true
    
    attr_reader :logged
    
    def initialize
      @logged = []
    end
    
    def debug(message)
      @logged << message
      puts(message) if self.class.print
    end

    def feed
      output = ''
      xml = Builder::XmlMarkup.new(:target => output, :indent => 2)
      xml.instruct!
      xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
        xml.id      "http://github.com/Fingertips/fingertips-backup"
        xml.link    "rel" => "self", "href" => "http://github.com/Fingertips/fingertips-backup"
        xml.updated Time.now.iso8601
        xml.author  { xml.name "Backup" }
        xml.title   "Backup feed"
        
        xml.entry do
          xml.id      "http://github.com/Fingertips/fingertips-backup"
          xml.updated Time.now.iso8601
          xml.title   @logged.last
          xml.summary @logged.last
          xml.content @logged.join("\n")
        end
      end
      output
    end
    
    def write_feed(path)
      File.open(path, 'w') { |f| f << feed }
    end
  end
end
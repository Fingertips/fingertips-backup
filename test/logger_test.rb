require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::Logger" do
  before do
    @logger = Fingertips::Logger.new
  end
  
  it "should store any debug messages" do
    @logger.debug "foo"
    @logger.debug "bar"
    @logger.debug "baz"
    
    @logger.logged.should == %w{ foo bar baz }
  end
end
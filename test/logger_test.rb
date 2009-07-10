require File.expand_path('../test_helper', __FILE__)

describe "Fingertips::Logger" do
  TMP_FEED = '/tmp/backup_feed'
  
  before do
    @logger = Fingertips::Logger.new
    @logger.debug "foo"
    @logger.debug "bar"
    @logger.debug "baz"
  end
  
  after do
    FileUtils.rm_rf TMP_FEED
  end
  
  it "should store any debug messages" do
    @logger.logged.should == %w{ foo bar baz }
  end
  
  it "should create a feed" do
    @logger.feed.should.include "foo\nbar\nbaz"
  end
  
  it "should write the feed to a given path" do
    now = Time.now
    Time.stubs(:now).returns(now)
    
    @logger.write_feed(TMP_FEED)
    File.read(TMP_FEED).should == @logger.feed
  end
end
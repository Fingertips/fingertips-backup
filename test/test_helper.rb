require "rubygems"
require "test/spec"
require "mocha"

$:.unshift File.expand_path('../../lib', __FILE__)

FIXTURES = File.expand_path('../fixtures', __FILE__)

class Test::Unit::TestCase
  def fixture(fixture)
    File.join(FIXTURES, fixture)
  end
  
  def fixture_read(fixture)
    File.read(self.fixture(fixture))
  end
end
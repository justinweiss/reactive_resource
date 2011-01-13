require 'rubygems'
require 'test/unit'
require 'reactive_resource'
require 'test_objects'

require 'shoulda'

require 'webmock/test_unit'
class Test::Unit::TestCase
  include WebMock::API
end

WebMock.disable_net_connect!

ReactiveResource::Base.site = 'https://api.avvo.com/1'

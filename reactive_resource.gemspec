# -*- encoding: utf-8 -*-
rails_version = ENV.key?('RAILS_VERSION') ? "~> #{ENV['RAILS_VERSION']}" : ['>= 3.0', '~> 3.1.0']
$:.push File.expand_path("../lib", __FILE__)
require "reactive_resource/version"

Gem::Specification.new do |s|
  s.name        = "reactive_resource"
  s.version     = ReactiveResource::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Justin Weiss"]
  s.email       = ["justin@uberweiss.org"]
  s.homepage    = ""
  s.summary     = %q{ActiveRecord-like associations for ActiveResource}
  s.description = %q{ActiveRecord-like associations for ActiveResource}

  s.rubyforge_project = "reactive_resource"

  s.add_dependency "activeresource", rails_version
  s.add_dependency "activesupport", rails_version
  s.add_development_dependency "shoulda", '~> 2.11.3'
  s.add_development_dependency "webmock", '~> 1.6.1'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

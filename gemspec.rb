# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "f5-icontrol/version"

Gem::Specification.new do |s|
  s.name        = "f5-icontrol"
  s.version     = F5::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jos Backus"]
  s.email       = ["jos@catnook.com"]
  s.homepage    = ""
  s.summary     = %q{F5 iControl interface}
  s.description = %q{This gem wraps SOAP4R to make it easy to talk to F5 load balancers using the iControl interface.}

  #s.rubyforge_project = "f5-icontrol"
  s.add_dependency "soap4r", ">= 1.5.8"

  s.files         = `git ls-files`.split("\n")
  #s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  #s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

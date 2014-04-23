# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "adl-utils/version"
Gem::Specification.new do |s|
  s.name        = "adl-utils"
  s.version     = Middleman::ADLUTILS::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["ALDO DIGITAL LAB"]
  # s.email       = ["email@example.com"]
  # s.homepage    = "http://example.com"
  s.summary     = %q{A short summary of your extension}
  s.description = %q{A longer description of your extension}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # The version of middleman-core your extension depends on
  s.add_runtime_dependency("middleman-core", [">= 3.2.2"])

  # Additional dependencies
  s.add_dependency("thor", [">= 0.15.2", "< 2.0"])
  s.add_dependency 'net-ftp-list', '>= 2.1.1'
  s.add_dependency 'god', '>=0.13.4'
end

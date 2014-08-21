require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'simplecov'
require 'simplecov-lcov'
SimpleCov::Formatter::LcovFormatter.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start 'middleman'

require 'coveralls'
Coveralls.wear!

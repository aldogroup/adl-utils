require 'rubygems' unless defined?(Gem)

require 'codeclimate-test-reporter'
SimpleCov.command_name 'Unit Tests'
CodeClimate::TestReporter.start

require 'bundler'
Bundler::GemHelper.install_tasks

require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:cucumber, 'Run features that should pass') do |t|
  t.cucumber_opts = "--color --tags ~@wip --strict --format #{ENV['CUCUMBER_FORMAT'] || 'Fivemat'}"
end

# require 'rubocop/rake_task'

# Rubocop::RakeTask.new

require 'rubocop/rake_task'
desc 'Run RuboCop to check code consistency'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = false
end

require 'rake/clean'

task test: ['cucumber']

task default: :test

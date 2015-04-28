require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'dotenv/tasks'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new

task default: [:lint, :spec]
task test: :spec
task lint: :rubocop

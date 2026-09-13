# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList[File.join('test', '**', '*_test.rb')].exclude(%r{\Atest/system/})
  t.verbose = false
  t.warning = false
end

# examples/app/assets/builds/ is gitignored, so a clean checkout has no compiled
# Tailwind CSS until this runs. test:system depends on it so the docs app it drives
# never 404s on its own stylesheet, locally or in CI.
task :build_examples_css do
  Dir.chdir('examples') { sh 'bundle exec rake tailwindcss:build' }
end

Rake::TestTask.new('test:system' => :build_examples_css) do |t|
  t.libs << 'test'
  t.pattern = 'test/system/**/*_test.rb'
  t.verbose = false
  t.warning = false
end

task default: :test

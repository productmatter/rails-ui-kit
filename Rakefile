# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'

# examples/app/assets/builds/ is gitignored, so a clean checkout has no compiled
# Tailwind CSS until this runs. Both lanes depend on it: the docs layout links the
# stylesheet, and Propshaft raises on a missing asset, so any test that renders a docs
# page (test/docs_params_test.rb, the browser lane) would 500 in CI without it.
task :build_examples_css do
  Dir.chdir('examples') { sh 'bundle exec rake tailwindcss:build' }
end

Rake::TestTask.new(test: :build_examples_css) do |t|
  t.libs << 'test'
  t.test_files = FileList[File.join('test', '**', '*_test.rb')].exclude(%r{\Atest/system/})
  t.verbose = false
  t.warning = false
end

Rake::TestTask.new('test:system' => :build_examples_css) do |t|
  t.libs << 'test'
  t.pattern = 'test/system/**/*_test.rb'
  t.verbose = false
  t.warning = false
end

task default: :test

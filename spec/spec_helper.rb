# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "spec/"
end

require "data_customs"
require "open3"

module TestHelpers
  def run_command(cmd, chdir:)
    stdout_str, stderr_str, status = Open3.capture3(cmd, chdir: chdir)

    [stdout_str, stderr_str, status]
  end

  def dummy_app_root
    File.expand_path("dummy", __dir__)
  end
end

RSpec.configure do |config|
  Dir["spec/support/**/*.rb"].each { |f| require File.expand_path(f) }

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include TestHelpers
end

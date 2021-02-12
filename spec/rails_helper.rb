# frozen_string_literal: true

# Start SimpleCov
require "spec_helper"

# Load the dummy app
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../fixtures/dummy/config/environment", __FILE__)

# Load up RSpec
require "rspec/rails"

RSpec.configure do |config|
  # rspec-rails configuration
  config.filter_rails_from_backtrace!
  config.infer_spec_type_from_file_location!
  config.render_views
end

# frozen_string_literal: true

module BuildConfiguration
  def build(attributes)
    require "ravioli/configuration"
    Ravioli::Configuration.new(attributes)
  end

  def empty
    build({})
  end
end

RSpec.configure do |config|
  config.include BuildConfiguration

  config.before do
    ENV["RAILS_MASTER_KEY"] = nil
    ENV["STAGING"] = nil
    Ravioli.configurations.clear
  end
end

# frozen_string_literal: true

require "ravioli"

unless defined?(::App)
  App = Ravioli.build {
    # Automatically infer a `staging?` status
    self.staging = Rails.env.production? && ENV["STAGING"].present?

    # Load config/**/*.yml files (except for locales)
    config_dir = Rails.root.join("config")
    Dir[config_dir.join("{[!locales/]**/*,*}.yml")].each do |config_file|
      load_config_file(config_file)
    end

    load_credentials("credentials", key_path: "master", env_name: "base")
    load_credentials("credentials/#{Rails.env}", env_name: "master")
    load_credentials("credentials/staging") if staging?
  }
end

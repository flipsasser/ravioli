# frozen_string_literal: true

require "active_support/all"
require_relative "configuration"

module Ravioli
  # The Builder clas provides a simple interface for building a Ravioli configuration. It has
  # methods for loading configuration files and encrypted credentials, and forwards direct
  # configuration on to the configuration instance. This allows us to keep a clean separation of
  # concerns (builder: loads configuration details; configuration: provides access to information
  # in memory).
  class Builder
    def initialize(class_name: "Configuration", namespace: nil)
      configuration_class = if namespace.present?
        namespace.class_eval <<-EOC, __FILE__, __LINE__ + 1
          class #{class_name.to_s.classify} < Ravioli::Configuration; end
        EOC
        namespace.const_get(class_name)
      else
        Ravioli::Configuration
      end
      @configuration = configuration_class.new
    end

    # Automatically infer a `staging?` status
    def add_staging_flag!
      configuration.staging = Rails.env.production? && ENV["STAGING"].present?
      Rails.env.class_eval("def staging?; true; end", __FILE__, __LINE__) if configuration.staging?
    end

    # Load config/**/*.yml files (except for locales)
    def auto_load_config_files!
      config_dir = Rails.root.join("config")
      Dir[config_dir.join("{[!locales/]**/*,*}.yml")].each do |config_file|
        load_config_file(config_file)
      end
    end

    # Load config/credentials**/*.yml.enc files (assuming we can find a key)
    def auto_load_credentials!
      load_credentials(key_path: "master", env_name: "base")
      load_credentials("credentials/#{Rails.env}", env_name: "master")
      load_credentials("credentials/staging") if configuration.staging?
    end

    # When the builder is done working, lock the configuration and return it
    def build!
      configuration.lock!
      configuration
    end

    # Load a config file either with a given path or by name (e.g. `config/whatever.yml` or `:whatever`)
    def load_config_file(path)
      config = parse_config_file(path)
      puts "Loading config:"
      pp config
      configuration.append(config) if config.present?
    end

    # Load secure credentials using a key either from a file or the ENV
    def load_credentials(path = "credentials", key_path: path, env_name: path.split("/").last)
      credentials = parse_credentials(path, env_name: env_name, key_path: key_path)
      puts "Loading credentials:"
      pp credentials
      configuration.append(credentials) if credentials.present?
    end

    private

    attr_reader :configuration

    # rubocop:disable Style/MethodMissingSuper
    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(*args, &block)
      configuration.send(*args, &block)
    end

    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper
    def parse_config_file(path)
      path = path_to_config_file_path(path)
      name = File.basename(path, File.extname(path))
      name = File.dirname(path) if name == "config"
      {
        name => Rails.application.config_for(
          path,
          env: staging? ? "staging" : Rails.env,
        ),
      }
    rescue RuntimeError => error
      warn "Could not load config file #{path}", error
      {}
    end

    def parse_credentials(path, key_path: path, env_name: path.split("/").last)
      env_name = env_name.to_s
      env_name = "RAILS_#{env_name.upcase}_KEY" unless env_name.upcase == env_name
      options = {key_path: "config/#{key_path}.key"}
      options[:env_key] = ENV[env_name].present? ? env_name : SecureRandom.hex(6)

      credentials = Rails.application.encrypted("config/#{path}.yml.enc", options)&.config || {}
      credentials.symbolize_keys
    rescue ActiveSupport::MessageEncryptor::InvalidMessage => error
      warn "Invalid key for `#{env_name}'; could not load credentials at config/#{path}.yml.enc with key file config/#{key_path}.key or ENV key #{env_name}", error
      {}
    end

    def path_to_config_file_path(path)
      puts "converting #{path} to pathname"
      unless path.is_a?(Pathname)
        path = path.to_s
        path = path.match?(Pathname::SEPARATOR_PAT) ? Pathname.new(path) : Pathname.new("config").join(path)
      end
      # binding.pry
      puts "got #{path.inspect}"
      path
    end

    def warn(message, error)
      message = "[#{Ravioli::NAME}] #{message}:\n\n#{error.cause.inspect}"
      Rails.logger.warn(message) if defined? Rails
      $stderr.write message # rubocop:disable Rails/Output
    end
  end
end

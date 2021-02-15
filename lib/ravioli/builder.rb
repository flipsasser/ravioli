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
    def initialize(class_name: "Configuration", namespace: nil, strict: false)
      configuration_class = if namespace.present?
        namespace.class_eval <<-EOC, __FILE__, __LINE__ + 1
          class #{class_name.to_s.classify} < Ravioli::Configuration; end
        EOC
        namespace.const_get(class_name)
      else
        Ravioli::Configuration
      end
      @strict = !!strict
      @configuration = configuration_class.new
    end

    # Automatically infer a `staging?` status
    def add_staging_flag!(is_staging = Rails.env.production? && ENV["STAGING"].present?)
      configuration.staging = is_staging
      Rails.env.class_eval("def staging?; Ravioli.default&.staging?; end", __FILE__, __LINE__)
      is_staging
    end

    # Load YAML or JSON files in config/**/* (except for locales)
    def auto_load_config_files!
      config_dir = Rails.root.join("config")
      Dir[config_dir.join("{[!locales/]**/*,*}.{json,yaml,yml}")].each do |config_file|
        load_config_file(config_file, key: !File.basename(config_file, File.extname(config_file)).casecmp("app").zero?)
      end
    end

    # Load config/credentials**/*.yml.enc files (assuming we can find a key)
    def auto_load_credentials!
      # Load the base config
      load_credentials(key_path: "config/master.key", env_name: "base")

      # Load any environment-specific configuration on top of it
      load_credentials("config/credentials/#{Rails.env}", key_path: "config/credentials/#{Rails.env}.key", env_name: "master")

      # Apply staging configuration on top of THAT, if need be
      load_credentials("config/credentials/staging", key_path: "config/credentials/staging.key") if configuration.staging?
    end

    # When the builder is done working, lock the configuration and return it
    def build!
      configuration.freeze
    end

    # Load a config file either with a given path or by name (e.g. `config/whatever.yml` or `:whatever`)
    def load_config_file(path, options = {})
      config = parse_config_file(path, options)
      configuration.append(config) if config.present?
    rescue => error
      warn "Could not load config file #{path}", error
    end

    # Load secure credentials using a key either from a file or the ENV
    def load_credentials(path = "credentials", key_path: path, env_name: path.split("/").last)
      credentials = parse_credentials(path, env_name: env_name, key_path: key_path)
      configuration.append(credentials) if credentials.present?
    rescue => error
      warn "Could not decrypt `#{path}.yml.enc' with key file `#{key_path}' or `ENV[\"#{env_name}\"]'", error
      {}
    end

    private

    ENV_KEYS = %w[default development production shared staging test].freeze
    EXTNAMES = %w[yml yaml json].freeze

    attr_reader :configuration

    def extract_environmental_config(config)
      # Check if the config hash is keyed by environment - if not, just return it as-is. It's
      # considered "keyed by environment" if it contains ONLY env-specific keys.
      return config unless (config.keys & ENV_KEYS).any? && (config.keys - ENV_KEYS).empty?

      # Combine environmental config in the following order:
      # 1. Shared config
      # 2. Environment-specific
      # 3. Staging-specific (if we're in a staging environment)
      environments = ["shared", Rails.env.to_s]
      environments.push("staging") if configuration.staging?
      config.values_at(*environments).inject({}) { |final_config, environment_config|
        final_config.deep_merge((environment_config || {}))
      }
    end

    # rubocop:disable Style/MethodMissingSuper
    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(*args, &block)
      configuration.send(*args, &block)
    end
    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper

    def parse_config_file(path, options = {})
      path = path_to_config_file_path(path)

      config = case path.extname.downcase
      when ".json"
        parse_json_config_file(path)
      when ".yml", ".yaml"
        parse_yaml_config_file(path)
      else
        raise ParseError.new("#{Ravioli::NAME} doesn't know how to parse #{path}")
      end

      # At least expect a hash to be returned from the loaded config file
      return {} unless config.is_a?(Hash)

      # Extract a merged config based on the Rails.env (if the file is keyed that way)
      config = extract_environmental_config(config)

      # Key the configuration according the passed-in options
      key = options.delete(:key)
      return config if key == false # `key: false` means don't key the configuration at all

      if key == true
        # `key: true` means key it automatically based on the filename
        name = File.basename(path, File.extname(path))
        name = File.dirname(path).split(Pathname::SEPARATOR_PAT).last if name.casecmp("config").zero?
      else
        # `key: :anything_else` means use `:anything_else` as the key
        name = key.to_s
      end

      {name => config}
    end

    def parse_credentials(path, key_path: path, env_name: path.split("/").last)
      env_name = env_name.to_s
      env_name = "RAILS_#{env_name.upcase}_KEY" unless env_name.upcase == env_name
      key_path = path_to_config_file_path(key_path, extnames: "key", quiet: true)
      options = {key_path: key_path}
      options[:env_key] = ENV[env_name].present? ? env_name : SecureRandom.hex(6)

      path = path_to_config_file_path(path, extnames: "yml.enc")
      credentials = Rails.application.encrypted(path, options)&.config || {}
      credentials
    end

    def parse_json_config_file(path)
      contents = File.read(path)
      JSON.parse(contents).deep_transform_keys { |key| key.to_s.underscore }
    end

    def parse_yaml_config_file(path)
      require "erb"
      contents = File.read(path)
      erb = ERB.new(contents).tap { |renderer| renderer.filename = path.to_s }
      YAML.safe_load(erb.result, aliases: true)
    end

    def path_to_config_file_path(path, extnames: EXTNAMES, quiet: false)
      original_path = path.dup
      unless path.is_a?(Pathname)
        path = path.to_s
        path = path.match?(Pathname::SEPARATOR_PAT) ? Pathname.new(path) : Pathname.new("config").join(path)
      end
      path = Rails.root.join(path) unless path.absolute?

      # Try to guess an extname, if we weren't given one
      if path.extname.blank?
        Array(extnames).each do |extname|
          other_path = path.sub_ext(".#{extname}")
          if other_path.exist?
            path = other_path
            break
          end
        end
      end

      warn "Could not resolve a configuration file at #{original_path.inspect}" unless quiet || path.exist?

      path
    end

    def warn(message, error = $!)
      message = "[#{Ravioli::NAME}] #{message}"
      message = "#{message}:\n\n#{error.cause.inspect}" if error&.cause.present?
      if @strict
        raise BuildError.new(message, error)
      else
        Rails.logger.warn(message) if defined? Rails
        $stderr.write message # rubocop:disable Rails/Output
      end
    end
  end

  class BuildError < StandardError
    def initialize(message, cause = nil)
      super message
      @cause = cause
    end

    def cause
      @cause || super
    end
  end
  class ParseError < StandardError; end
end

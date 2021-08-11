# frozen_string_literal: true

require "active_support/all"
require "erb"
require_relative "configuration"

module Ravioli
  # The Builder class provides a simple interface for building a Ravioli configuration. It has
  # methods for loading configuration files and encrypted credentials, and forwards direct
  # configuration on to the configuration instance. This allows us to keep a clean separation of
  # concerns (builder: loads configuration details; configuration: provides access to information
  # in memory).
  #
  # == ENV variables and encrypted credentials keys
  #
  # <table><thead><tr><th>File</th><th>First it tries...</th><th>Then it tries...</th></tr></thead><tbody><tr><td>
  #
  # `config/credentials.yml.enc`
  #
  # </td><td>
  #
  # `ENV["RAILS_BASE_KEY"]`
  #
  # </td><td>
  #
  # `ENV["RAILS_MASTER_KEY"]`
  #
  # </td></tr><tr><td>
  #
  # `config/credentials/production.yml.enc`

  # </td><td>
  #
  # `ENV["RAILS_PRODUCTION_KEY"]`
  #
  # </td><td>
  #
  # `ENV["RAILS_MASTER_KEY"]`
  #
  # </td></tr><tr><td>
  #
  # `config/credentials/staging.yml.enc` (only if running on staging)
  #
  # </td><td>
  #
  # `ENV["RAILS_STAGING_KEY"]`
  #
  # </td><td>
  #
  # `ENV["RAILS_MASTER_KEY"]`
  #
  # </td></tr></tbody></table>
  class Builder
    def initialize(class_name: "Configuration", hijack: false, namespace: nil, strict: false)
      configuration_class = if namespace.present?
        namespace.class_eval <<-EOC, __FILE__, __LINE__ + 1
          # class Configuration < Ravioli::Configuration; end
          class #{class_name.to_s.classify} < Ravioli::Configuration; end
        EOC
        namespace.const_get(class_name)
      else
        Ravioli::Configuration
      end
      @strict = !!strict
      @configuration = configuration_class.new
      @reload_credentials = Set.new
      @reload_paths = Set.new
      @hijack = !!hijack

      if @hijack
        # Put this builder on the configurations stack - it will intercept setters on the underyling
        # configuration object as it loads files, and mark those files as needing a reload once
        # loading is complete
        Ravioli.configurations.push(self)
      end
    end

    # Automatically infer a `staging` status from the current environment
    #
    # @param is_staging [boolean, #present?] whether or not the current environment is considered a staging environment
    def add_staging_flag!(is_staging = Rails.env.production? && ENV["STAGING"].present?)
      is_staging = is_staging.present?
      configuration.staging = is_staging
    end

    # Iterates through the config directory (including nested folders) and
    # calls {Ravioli::Builder::load_file} on each JSON or YAML file it
    # finds. Ignores `config/locales`.
    def auto_load_files!
      config_dir = Rails.root.join("config")
      Dir[config_dir.join("{[!locales/]**/*,*}.{json,yaml,yml}")].each do |config_file|
        auto_load_file(config_file)
      end
    end

    # Loads Rails encrypted credentials that it can. Checks for corresponding private key files, or ENV vars based on the {Ravioli::Builder credentials preadmlogic}
    def auto_load_credentials!
      # Load the root config (supports using the master key or `RAILS_ROOT_KEY`)
      load_credentials(
        key_path: "config/master.key",
        env_names: %w[master root],
        quiet: true,
      )

      # Load any environment-specific configuration on top of it. Since Rails will try
      # `RAILS_MASTER_KEY` from the environment, we assume the same
      load_credentials(
        "config/credentials/#{Rails.env}",
        key_path: "config/credentials/#{Rails.env}.key",
        env_names: ["master"],
        quiet: true,
      )

      # Apply staging configuration on top of THAT, if need be
      if configuration.staging?
        load_credentials(
          "config/credentials/staging",
          env_names: %w[staging master],
          key_path: "config/credentials/staging.key",
          quiet: true,
        )
      end
    end

    # When the builder is done working, lock the configuration and return it
    def build!
      if @hijack
        # Replace this builder with the underlying configuration on the configurations stack...
        Ravioli.configurations.delete(self)
        Ravioli.configurations.push(configuration)

        # ...and then reload any config file that referenced the configuration the first time it was
        # loaded!
        @reload_paths.each do |path|
          auto_load_file(path)
        end
      end

      configuration.freeze
    end

    # Load a file either with a given path or by name (e.g. `config/whatever.yml` or `:whatever`)
    def load_file(path, options = {})
      config = parse_config_file(path, options)
      configuration.append(config) if config.present?
    rescue => error
      warn "Could not load config file #{path}", error
    end

    # Load secure credentials using a key either from a file or the ENV
    def load_credentials(path = "credentials", key_path: path, env_names: path.split("/").last, quiet: false)
      error = nil
      env_names = Array(env_names).map { |env_name| parse_env_name(env_name) }
      env_names.each do |env_name|
        credentials = parse_credentials(path, env_name: env_name, key_path: key_path, quiet: quiet)
        if credentials.present?
          configuration.append(credentials)
          return credentials
        end
      rescue => e
        error = e
      end

      if error
        attempted_names = ["key file `#{key_path}'"]
        attempted_names.push(*env_names.map { |env_name| "`ENV[\"#{env_name}\"]'" })
        attempted_names = attempted_names.to_sentence(two_words_connector: " or ", last_word_connector: ", or ")
        warn(
          "Could not decrypt `#{path}.yml.enc' with #{attempted_names}",
          error,
          critical: false,
        )
      end

      {}
    end

    private

    ENV_KEYS = %w[default development production shared staging test].freeze
    EXTNAMES = %w[yml yaml json].freeze

    attr_reader :configuration

    def auto_load_file(config_file)
      basename = File.basename(config_file, File.extname(config_file))
      dirname = File.dirname(config_file)
      key = %w[app application].exclude?(basename) && dirname != config_dir
      load_file(config_file, key: key)
    end

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
      if @current_path
        @reload_paths.add(@current_path)
      end

      if @current_credentials
        @reload_credentials.add(@current_credentials)
      end

      configuration.send(*args, &block)
    end
    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper

    def parse_config_file(path, options = {})
      # Stash a reference to the file we're parsing, so we can reload it later if it tries to use
      # the configuration object
      @current_path = path
      path = path_to_config_file_path(path)

      config = case path.extname.downcase
      when ".json"
        parse_json_config_file(path)
      when ".yml", ".yaml"
        parse_yaml_config_file(path)
      else
        raise ParseError.new("Ravioli doesn't know how to parse #{path}")
      end

      # We are no longer loading anything
      @current_path = nil
      # At least expect a hash to be returned from the loaded config file
      return {} unless config.is_a?(Hash)

      # Extract a merged config based on the Rails.env (if the file is keyed that way)
      config = extract_environmental_config(config)

      # Key the configuration according the passed-in options
      key = options.delete(:key) { true }
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

    def parse_env_name(env_name)
      env_name = env_name.to_s
      env_name.match?(/^RAILS_/) ? env_name : "RAILS_#{env_name.upcase}_KEY"
    end

    def parse_credentials(path, key_path: path, env_name: path.split("/").last, quiet: false)
      @current_credentials = path
      env_name = parse_env_name(env_name)
      key_path = path_to_config_file_path(key_path, extnames: "key", quiet: true)
      options = {key_path: key_path.to_s}
      options[:env_key] = ENV[env_name].present? ? env_name : "__RAVIOLI__#{SecureRandom.hex(6)}"

      path = path_to_config_file_path(path, extnames: "yml.enc", quiet: quiet)
      (Rails.application.encrypted(path, **options)&.config || {}).tap do
        @current_credentials = nil
      end
    end

    def parse_json_config_file(path)
      contents = File.read(path)
      JSON.parse(contents).deep_transform_keys { |key| key.to_s.underscore }
    end

    def parse_yaml_config_file(path)
      contents = File.read(path)
      erb = ERB.new(contents).tap { |renderer| renderer.filename = path.to_s }
      YAML.safe_load(erb.result, [Symbol], aliases: true)
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

    def warn(message, error = $!, critical: true)
      message = "[Ravioli] #{message}"
      message = "#{message}:\n\n#{error.cause.inspect}" if error&.cause.present?
      if @strict && critical
        raise BuildError.new(message, error)
      else
        Rails.logger.try(:warn, message) if defined? Rails
        $stderr.write message # rubocop:disable Rails/Output
      end
    end
  end

  # Error raised when Ravioli is in strict mode. Includes the original error for context.
  class BuildError < StandardError
    def initialize(message, cause = nil)
      super message
      @cause = cause
    end

    def cause
      @cause || super
    end
  end

  # Error raised when Ravioli encounters a problem parsing a file
  class ParseError < StandardError; end
end

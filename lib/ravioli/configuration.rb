# frozen_string_literal: true

require "ostruct"
# require "ravioli/class_methods"

module Ravioli
  class Configuration < OpenStruct
    # extend Ravioli::ClassMethods
    # include Ravioli::InstanceMethods

    attr_writer :root_key

    def initialize(attributes = {})
      super({})
      append(attributes)
    end

    def append(attributes = {})
      puts "appending #{attributes.inspect}"
      attributes.each do |key, value|
        key = key.to_s
        if value.is_a?(Hash)
          original_value = self[key]
          merged_value = original_value.is_a?(self.class) ? original_value.to_hash.deep_merge(value) : value
          credential_value = self.class.new(merged_value)
          self[key] = credential_value
        else
          self[key] = value
        end
      end
    end

    def dig(*keys, safe: false)
      root_key = self.class.root_key
      env_keys = root_key.present? && env_keys.first.to_s == root_key.to_s ? keys[-1..1] : keys

      env_key = env_keys.join("_").upcase
      ENV.fetch(env_key) do
        value = self
        keys.each do |key|
          value = value[key.to_s]
          break if value.blank?
        end

        value
      end
    end

    def dig!(*keys)
      fetch(*keys) { raise KeyMissingError.new("Could not find value at key path #{keys.inspect}") }
    end

    def fetch(*keys)
      dig(*keys) || yield
    end

    def load_config_file(path)
      config = parse_config_file(path)
      pp config
      append(config)
    end

    def load_credentials(path, key_path: path, env_name: path.split("/").last)
      credentials = parse_credentials(path, env_name: env_name, key_path: key_path)
      pp credentials
      append(credentials)
    end

    # def pretty_print(printer = nil)
    #   to_hash.pretty_print(printer)
    # end

    def root_key
      return @root_key if defined? @root_key
      @root_key = :app
    end

    def safe(*keys)
      fetch(*keys) { self.class.new }
    end

    def to_hash
      @table || {}
    end

    private

    def parse_config_file(path)
      path = case path
      when Symbol
        Rails.root.join("config", "#{path}.yml")
      else
        Pathname.new(File.expand_path(path))
      end
      name = File.basename(path, File.extname(path))
      name = File.dirname(path) if name == "config"
      {
        name => Rails.application.config_for(
          path,
          env: staging? ? "staging" : Rails.env,
        ),
      }
    rescue RuntimeError => error
      warn "Could not load config file config/#{service}.yml", error
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

    def warn(message, error)
      message = "[ConfigBuilder] #{message}:\n\n#{error.cause.inspect}"
      Rails.logger.warn(message)
      $stderr.write message # rubocop:disable Rails/Output
    end
  end
end

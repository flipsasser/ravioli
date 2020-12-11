# frozen_string_literal: true

module Ravioli
  module ClassMethods
    def inspect
      @instance_to_s = true
      instance.inspect.tap { @instance_to_s = false }
    end

    def instance
      @instance ||= new
    end

    def load_config_file(path)
      config = parse_config_file(path)
      instance.append(config)
    end

    def load_credentials(path, key_path: path, env_name: path.split("/").last)
      credentials = parse_credentials(path, env_name: env_name, key_path: key_path)
      instance.append(credentials)
    end

    # private

    # rubocop:disable Style/MethodMissingSuper
    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(method, *args, &block)
      puts "#{method.inspect}: #{args.inspect}"
      if args.empty?
        result = instance[method.to_s.chomp("?")]
        if method.to_s.ends_with?("?")
          result.present?
        else
          result
        end
      elsif args.one? && method.to_s.ends_with?("=")
        instance[method] = args.first
      else
        instance.send(method, *args, &block)
      end
    end

    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper

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

    def pretty_print(printer)
      if @instance_to_s
        super
      else
        @instance_to_s = true
        instance.pretty_print(printer).tap { @instance_to_s = false }
      end
    end

    def root_key
      return @root_key if defined? @root_key
      @root_key = :app
    end

    def root_key=(new_root_key)
      @root_key = new_root_key
    end

    def to_s
      if @instance_to_s
        super
      else
        @instance_to_s = true
        binding.pry
        instance.to_s.tap { @instance_to_s = false }
      end
    end
    alias to_str to_s

    def warn(message, error)
      message = "[ConfigBuilder] #{message}:\n\n#{error.cause.inspect}"
      Rails.logger.warn(message)
      $stderr.write message # rubocop:disable Rails/Output
    end
  end
end

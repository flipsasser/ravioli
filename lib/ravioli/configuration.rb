# frozen_string_literal: true

require "active_support/all"
require "ostruct"

module Ravioli
  class Configuration < OpenStruct
    attr_accessor :key_path

    def initialize(attributes = {})
      super({})
      self.key_path = attributes.delete(:key_path)
      append(attributes)
    end

    def ==(other)
      other = other.to_hash if other.respond_to?(:to_hash)
      other = other.try(:with_indifferent_access) || other
      other == to_hash
    end

    def append(attributes = {})
      attributes.each do |key, value|
        key = key.to_s
        if value.is_a?(Hash)
          original_value = self[key]
          value = original_value.table.deep_merge(value.deep_symbolize_keys) if original_value.is_a?(self.class)
          self[key] = build(key, value)
        else
          self[key] = fetch_env_key_for(key) { value }
        end
      end
    end

    def dig(*keys, safe: false)
      return safe(*keys) if safe

      fetch_env_key_for(keys) do
        keys.inject(self) do |value, key|
          value = value[key]
          break if value.blank?
          value
        end
      end
    end

    def dig!(*keys)
      fetch(*keys) { raise KeyMissingError.new("Could not find value at key path #{keys.inspect}") }
    end

    def fetch(*keys)
      dig(*keys) || yield
    end

    def pretty_print(printer = nil)
      pretty = to_hash.pretty_print(printer)
      if key_path.present?
        pretty
      else
        "#<#{self.class.name} #{pretty}>"
      end
    end

    def safe(*keys)
      fetch(*keys) { build(keys) }
    end

    def to_hash
      if !@modifiable
        @_to_hash ||= table.except(:key_path)
      else
        table.except(:key_path)
      end
    end
    alias as_hash to_hash
    alias as_json to_hash

    private

    def build(keys, attributes = {})
      attributes[:key_path] = key_path_for(keys)
      child = self.class.new(attributes)
      child.freeze if @locked
      child
    end

    def fetch_env_key_for(keys, &block)
      env_key = key_path_for(keys).join("_").upcase
      ENV.fetch(env_key, &block)
    end

    def key_path_for(keys)
      Array(key_path) + Array(keys)
    end

    # rubocop:disable Style/MethodMissingSuper
    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(missing_method, *args, &block)
      # Return proper booleans from query methods
      return super.present? if args.empty? && missing_method.to_s.ends_with?("?")
      super
    end
    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper
  end

  class KeyMissingError < StandardError; end
end

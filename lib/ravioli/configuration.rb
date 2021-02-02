# frozen_string_literal: true

require "active_support/all"
require "ostruct"

module Ravioli
  class Configuration < OpenStruct
    attr_reader :key_path

    def initialize(attributes = {})
      super({})
      @key_path = attributes.delete(:key_path)
      append(attributes)
    end

    # def ==(other)
    #   other = other.table if other.respond_to?(:table)
    #   other == table
    # end

    def append(attributes = {})
      attributes.each do |key, value|
        self[key.to_sym] = cast(key.to_sym, value)
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
      table.pretty_print(printer)
    end

    def safe(*keys)
      fetch(*keys) { build(keys) }
    end

    private

    def build(keys, attributes = {})
      attributes[:key_path] = key_path_for(keys)
      child = self.class.new(attributes)
      child.freeze if frozen?
      child
    end

    def cast(key, value)
      if value.is_a?(Hash)
        original_value = dig(*Array(key))
        value = original_value.table.deep_merge(value.deep_symbolize_keys) if original_value.is_a?(self.class)
        build(key, value)
      else
        fetch_env_key_for(key) {
          if value.is_a?(Array)
            value.each_with_index.map { |subvalue, index| cast(Array(key) + [index], subvalue) }
          else
            value
          end
        }
      end
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
    def method_missing(method, *args, &block)
      # Return proper booleans from query methods
      return send(method.to_s.chomp("?")).present? if args.empty? && method.to_s.ends_with?("?")
      super
    end
    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper
  end

  class KeyMissingError < StandardError; end
end

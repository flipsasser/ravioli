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

    def []=(*args)
      avoid_write_lock!
      super
    end

    def append(attributes = {})
      avoid_write_lock!
      attributes.each do |key, value|
        key = key.to_s
        if value.is_a?(Hash)
          original_value = self[key]
          merged_value = original_value.is_a?(self.class) ? original_value.to_hash.deep_merge(value) : value
          credential_value = build(key, merged_value)
          self[key] = credential_value
        else
          self[key] = fetch_env_key_for(key) { value }
        end
      end
    end

    def dig(*keys, safe: false)
      return safe(*keys) if safe

      fetch_env_key_for(keys) do
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

    def lock!
      @locked = true
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
      if @locked
        @_to_hash ||= _ravioli_to_hash
      else
        _ravioli_to_hash
      end
    end
    alias as_hash to_hash
    alias as_json to_hash

    private

    def _ravioli_to_hash
      (@table || {}).with_indifferent_access.except(:key_path)
    end

    def avoid_write_lock!
      raise ReadOnlyError.new if @locked
    end

    def build(keys, attributes = {})
      attributes[:key_path] = key_path_for(keys)
      child = self.class.new(attributes)
      child.lock! if @locked
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
      method = missing_method.to_s
      if args.empty?
        result = self[method.chomp("?")]
        return method.ends_with?("?") ? result.present? : result
      elsif args.one? && method.ends_with?("=")
        avoid_write_lock!
      end

      super
    end
    # rubocop:enable Style/MissingRespondToMissing
    # rubocop:enable Style/MethodMissingSuper
  end

  class KeyMissingError < StandardError; end
  class ReadOnlyError < StandardError; end
end

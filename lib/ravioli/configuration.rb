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
          self[key] = value
        end
      end
    end

    def build(keys, attributes = {})
      attributes[:key_path] = Array(key_path) + Array(keys)
      child = self.class.new(attributes)
      child.lock! if @locked
      child
    end

    def dig(*keys, safe: false)
      return safe(*keys) if safe
      # env_keys = root_key.present? && env_keys.first.to_s == root_key.to_s ? keys[-1..1] : keys
      env_key = keys.join("_").upcase
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

    def lock!
      @locked = true
    end

    # def pretty_print(printer = nil)
    #   to_hash.pretty_print(printer)
    # end

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

    private

    def _ravioli_to_hash
      (@table || {}).with_indifferent_access.except(:key_path)
    end

    def avoid_write_lock!
      raise ReadOnlyError.new if @locked
    end

    # rubocop:disable Style/MethodMissingSuper
    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(method, *args, &block)
      method = method.to_s
      if args.empty?
        result = super method.chomp("?")
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

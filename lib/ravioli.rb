# frozen_string_literal: true

require "active_support/all"

# These are the basic building blocks of Ravioli
require_relative "ravioli/configuration"
require_relative "ravioli/version"

# The top-level Ravioli module contains helper methods for building configuration instances and
# accessing them, as well as the various classes that it relies on to build stuff
module Ravioli
  NAME = "Ravioli"

  class << self
    def build(namespace: nil, &block)
      require_relative "ravioli/builder"
      builder = Builder.new(namespace: namespace)
      yield builder if block_given?
      instances.push(builder.build!)
    end

    def default
      instances.first
    end

    def instances
      @instances ||= []
    end
  end
end

require_relative "ravioli/engine" if defined?(Rails)

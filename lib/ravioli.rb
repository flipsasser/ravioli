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
    def build(class_name: "Configuration", namespace: nil, strict: false, &block)
      require_relative "ravioli/builder"
      builder = Builder.new(class_name: class_name, namespace: namespace, strict: strict)
      yield builder if block_given?
      builder.build!.tap do |configuration|
        instances.push(configuration)
      end
    end

    def default
      instances.last
    end

    def instances
      @instances ||= []
    end
  end
end

require_relative "ravioli/engine" if defined?(Rails)

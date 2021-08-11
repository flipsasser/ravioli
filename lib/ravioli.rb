# frozen_string_literal: true

require "active_support/all"

# These are the basic building blocks of Ravioli
require_relative "ravioli/builder"
require_relative "ravioli/configuration"
require_relative "ravioli/version"

# The root namespace for all of Ravioli, and owner of two handly
# configuration-related class methods
module Ravioli
  class << self
    # Forwards arguments to a {Ravioli::Builder}. See
    # {Ravioli::Builder#new} for complete documentation.
    #
    # @param namespace [String, Module, Class] the name of, or a direct reference to, the module or class your Configuration class should namespace itself within
    # @param class_name [String] the name of the namespace's Configuration class
    # @param strict [boolean] whether or not the Builder instance should throw errors when there are errors loading configuration files or encrypted credentials
    def build(namespace: nil, class_name: "Configuration", strict: false, &block)
      builder = Builder.new(
        class_name: class_name,
        hijack: true,
        namespace: namespace,
        strict: strict,
      )
      yield builder if block
      builder.build!
    end

    # Returns a list of all of the configuration instances
    def configurations
      @configurations ||= []
    end

    # Returns the most-recently configured Ravioli instance that has been built with {Ravioli::build}.
    def default
      configurations.last
    end
  end
end

require_relative "ravioli/railtie" if defined?(Rails)

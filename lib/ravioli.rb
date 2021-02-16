# frozen_string_literal: true

require "active_support/all"

# These are the basic building blocks of Ravioli
require_relative "ravioli/builder"
require_relative "ravioli/configuration"
require_relative "ravioli/version"

##
# Ravioli contains helper methods for building Configuration instances and accessing them, as well
# as the Builder class for help loading configuration files and encrypted credentials
module Ravioli
  NAME = "Ravioli"

  class << self
    def build(class_name: "Configuration", namespace: nil, strict: false, &block)
      builder = Builder.new(class_name: class_name, namespace: namespace, strict: strict)
      yield builder if block_given?
      builder.build!.tap do |configuration|
        configurations.push(configuration)
      end
    end

    def default
      configurations.last
    end

    def configurations
      @configurations ||= []
    end
  end
end

require_relative "ravioli/engine" if defined?(Rails)

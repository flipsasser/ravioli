# frozen_string_literal: true

require "pry" # TODO: Remove
require "active_support"
require "ostruct"
require "ravioli/class_methods"
require "ravioli/instance_methods"
require "ravioli/version"

module Ravioli
  def self.build(root_key: :app, &block)
    ravioli = Class.new(OpenStruct) {
      extend Ravioli::ClassMethods
      include Ravioli::InstanceMethods

      cattr_accessor :root_key
    }
    ravioli.root_key = root_key
    ravioli.instance_eval(&block) if block_given?
    ravioli
  end
end

require "ravioli/engine" if defined? Rails

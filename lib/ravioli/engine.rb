# frozen_string_literal: true

module Ravioli
  class Engine < ::Rails::Engine
    # isolate_namespace Ravioli

    def self.bootstrap_config
      unless Ravioli.default
        Ravioli.build(namespace: Rails.application&.class&.module_parent, strict: Rails.env.production?) do |config|
          config.add_staging_flag!
          config.auto_load_config_files!
          config.auto_load_credentials!
        end
      end

      Rails.extend Ravioli::RailsConfig unless Rails.respond_to?(:config)
    end

    # Bootstrap Ravioli onto the Rails app
    initializer "ravioli" do |app|
      self.class.bootstrap_config
    end
  end

  module RailsConfig
    def config
      Ravioli.default
    end
  end
end

# if defined?(Rails) && Rails.respond_to?(:application) && Rails.application && !Rails.respond_to?(:config)
#   Ravioli::Engine.bootstrap_config
# end

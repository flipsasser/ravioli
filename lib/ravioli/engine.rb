# frozen_string_literal: true

module Ravioli
  class Engine < ::Rails::Engine
    # Bootstrap Ravioli onto the Rails app
    initializer "ravioli", before: "load_environment_config" do |app|
      Rails.extend Ravioli::Config unless Rails.respond_to?(:config)
    end
  end

  module Config
    def config
      Ravioli.default || Ravioli.build(namespace: Rails.application&.class&.module_parent, strict: Rails.env.production?) do |config|
        config.add_staging_flag!
        config.auto_load_config_files!
        config.auto_load_credentials!
      end
    end
  end
end

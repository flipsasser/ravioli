# frozen_string_literal: true

require_relative "./staging_inquirer"

module Ravioli
  module RailsConfig
    def config
      Ravioli.default || Ravioli.build(namespace: Rails.application&.class&.module_parent, strict: Rails.env.production?) do |config|
        config.add_staging_flag!
        config.auto_load_files!
        config.auto_load_credentials!
      end
    end
  end

  class Railtie < ::Rails::Railtie
    # Bootstrap Ravioli onto the Rails app
    Rails.env.class.prepend Ravioli::StagingInquirer
    Rails.extend Ravioli::RailsConfig unless Rails.respond_to?(:config)
  end
end

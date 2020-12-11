# frozen_string_literal: true

module Ravioli
  class Engine < ::Rails::Engine
    isolate_namespace Ravioli

    # Register Ravioli with the Rails app
    initializer "active_support" do |app|
      # binding.pry
    end
  end
end

# frozen_string_literal: true

module Ravioli
  # A module that we mix in to the `Rails.env` inquirer class to add some extra staging-related
  # metadata
  module StagingInquirer
    # Add a `name` method to `Rails.env` that will return "staging" for staging environments, and
    # otherwise the string's value
    def name
      staging? ? "staging" : to_s
    end

    # Add a `strict:` keyword to reduce `Rails.env.production && !Rails.env.staging` calls
    def production?(strict: false)
      is_production = super()
      return is_production unless strict && is_production

      is_production && !staging?
    end

    # Override staging inquiries to check against the current configuration
    def staging?
      Rails.try(:config)&.staging?
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.xdescribe "Ravioli::Engine" do
  describe "auto-loading" do
    it "loads up all YAML, JSON, and encrypted credentials from `config/**/*`" do
      expect(Rails.config).to eq({
        thing: true,
        another_thing: false,
      })
    end
  end
end

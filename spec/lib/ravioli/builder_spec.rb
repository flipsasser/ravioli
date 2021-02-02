# frozen_string_literal: true

require "rails_helper"
require "ravioli/builder"

RSpec.describe Ravioli::Builder do
  let(:builder) { described_class.new }
  let(:configuration) { builder.build! }

  describe "#add_staging_flag!"

  describe "#load_config_file" do
    it "loads env files given a symbol" do
      builder.load_config_file(:root_test)
      expect(configuration).to eq({
        root_test: {
          anything_else: false,
          whatever: true,
        },
      })
    end
  end

  describe "load_credentials"
end

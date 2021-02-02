# frozen_string_literal: true
# # frozen_string_literal: true

# require "rails_helper"

# RSpec.describe "Ravioli::Engine" do
#   describe "auto-loading" do
#     before { load "ravioli.rb" }

#     it "loads up YAML files from `config/**/*` using Rails.env" do
#       expect(Rails.config.env_test).to eq({
#         thing: true,
#         another_thing: false,
#       })
#     end

#     it "loads up YAML files from `config/**/*` that don't have env-specific sections" do
#       expect(Rails.config.root_test).to eq({
#         whatever: true,
#         anything_else: false,
#       })
#     end
#   end
# end

# frozen_string_literal: true

require "rails_helper"
require "ravioli/builder"

RSpec.describe Ravioli::Builder, "#add_staging_flag!" do
  let(:builder) { described_class.new(strict: true) }
  let(:configuration) { builder.build! }

  after do
    ENV["STAGING"] = nil
    Ravioli.configurations.clear
  end

  it "doesn't return `true` if Rails.env is not 'production'" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test")).at_most(10000).times
    ENV["STAGING"] = "1"
    builder.add_staging_flag!
    expect(configuration.staging?).to eq(false)
    expect(Rails.env.staging?).to eq(false)
  end

  it "doesn't return `true` if ENV['STAGING'] is not set" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")).at_most(10000).times
    ENV["STAGING"] = nil
    builder.add_staging_flag!
    expect(configuration.staging?).to eq(false)
    expect(Rails.env.staging?).to eq(false)
  end

  it "returns `true` if ENV['STAGING'] is set and Rails.env is 'production'" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")).at_most(10000).times
    ENV["STAGING"] = "1"
    builder.add_staging_flag!
    expect(configuration.staging?).to eq(true)
    expect(Rails.env.staging?).to eq(true)
  end
end

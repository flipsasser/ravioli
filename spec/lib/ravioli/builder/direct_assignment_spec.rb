# frozen_string_literal: true

require "rails_helper"
require "ravioli/builder"

RSpec.describe Ravioli::Builder, "direct assignment of config values" do
  let(:builder) { described_class.new(strict: true) }
  let(:configuration) { builder.build! }

  it "forwards values to the underlying configuration" do
    builder.test_maybe_things_work = true
    expect(configuration).to eq(build(test_maybe_things_work: true))
  end
end

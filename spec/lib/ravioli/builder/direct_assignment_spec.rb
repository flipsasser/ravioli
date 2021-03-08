# frozen_string_literal: true

require "spec_helper"
require "ravioli/builder"

RSpec.describe Ravioli::Builder, "#direct_assignment=" do
  let(:builder) { described_class.new(strict: true) }
  let(:configuration) { builder.build! }

  it "forwards values to the underlying configuration" do
    builder.direct_assignment = true
    expect(configuration).to eq(build(direct_assignment: true))
  end
end

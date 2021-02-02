# frozen_string_literal: true

require "rails_helper"
require "ravioli/builder"

RSpec.shared_examples :parses_various_inputs do |filetype|
  env_key = "#{filetype}_env_test".to_sym
  flat_key = "#{filetype}_test".to_sym

  it "loads env-keyed files given a symbol" do
    builder.load_config_file(env_key)
    expect(configuration).to eq(build(
      env_key => {
        another_thing: false,
        thing: true,
      },
    ))
  end

  it "loads flat files given a symbol" do
    builder.load_config_file(flat_key)
    expect(configuration).to eq(build(
      flat_key => {
        whatever: true,
        anything_else: false,
      },
    ))
  end

  it "loads env-keyed files given a filename" do
    builder.load_config_file("#{filetype}_env_test.#{filetype}")
    expect(configuration).to eq(build(
      env_key => {
        another_thing: false,
        thing: true,
      },
    ))
  end

  it "loads flat files given a filename" do
    builder.load_config_file("#{filetype}_test.#{filetype}")
    expect(configuration).to eq(build(
      flat_key => {
        whatever: true,
        anything_else: false,
      },
    ))
  end

  it "loads env-keyed files given a relative path" do
    builder.load_config_file("config/#{filetype}_env_test.#{filetype}")
    expect(configuration).to eq(build(
      env_key => {
        another_thing: false,
        thing: true,
      },
    ))
  end

  it "loads flat files given a relative path" do
    builder.load_config_file("config/#{filetype}_test.#{filetype}")
    expect(configuration).to eq(build(
      flat_key => {
        whatever: true,
        anything_else: false,
      },
    ))
  end

  it "loads env-keyed files given a full path" do
    builder.load_config_file(Rails.root.join("config", "#{filetype}_env_test.#{filetype}"))
    expect(configuration).to eq(build(
      env_key => {
        another_thing: false,
        thing: true,
      },
    ))
  end

  it "loads flat files given a full path" do
    builder.load_config_file(Rails.root.join("config", "#{filetype}_test.#{filetype}"))
    expect(configuration).to eq(build(
      flat_key => {
        whatever: true,
        anything_else: false,
      },
    ))
  end
end

RSpec.describe Ravioli::Builder, "#load_config_file" do
  let(:builder) { described_class.new(strict: true) }
  let(:configuration) { builder.build! }

  describe "with a non-existent file" do
    it "warns the user when not in strict mode" do
      expect {
        builder.load_config_file("nothing.json")
      }.to raise_error(Ravioli::BuildError)
    end
  end

  describe "with an un-parseable file" do
    it "warns the user when not in strict mode" do
      expect {
        builder.load_config_file("config/routes.rb")
      }.to raise_error(an_instance_of(Ravioli::BuildError).and(having_attributes(cause: an_instance_of(Ravioli::ParseError))))
    end
  end

  describe "with YAML files" do
    include_context :parses_various_inputs, :yml
  end

  describe "with JSON files" do
    include_context :parses_various_inputs, :json
  end
end

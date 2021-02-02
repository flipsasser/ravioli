# frozen_string_literal: true

require "spec_helper"
require "ravioli/configuration"

RSpec.describe Ravioli::Configuration do
  let(:configuration) { described_class.new(thing: {other_thing: {third_thing: true}}) }

  describe "#==" do
    it "returns `true` for configurations with equivalent hashes" do
      expect(described_class.new(thing: 1, other_thing: true)).to eq(described_class.new("thing" => 1, "other_thing" => true))
    end

    it "returns `false` for configurations with non-equivalent hashes" do
      expect(described_class.new(thing: 1, other_thing: true)).not_to eq(described_class.new(thing: 2, other_thing: true))
    end
  end

  describe "#append" do
    let(:configuration) { described_class.new }

    it "writes basic values directly to the config" do
      configuration.append(thing: 1, other_thing: true)
      expect(configuration.thing).to eq(1)
      expect(configuration.other_thing).to eq(true)
    end

    it "builds nested sub-hashes" do
      configuration.append(thing: {other_thing: {third_thing: true}})
      expect(configuration.thing.other_thing.third_thing).to eq(true)
    end

    it "ensures nested sub-hashes keep track of their keypaths" do
      configuration.append(thing: {other_thing: {third_thing: true}})
      expect(configuration.thing.other_thing.key_path).to eq(%w[thing other_thing])
    end
  end

  describe "#dig" do
    it "returns values it finds" do
      expect(configuration.dig(:thing, :other_thing)).to eq({third_thing: true})
    end

    it "returns nil when it can't find something" do
      expect(configuration.dig(:non, :existant, :thing)).to be_nil
    end

    it "returns a blank config file when it can't find something and is passed a truthy `safe:` keyword" do
      dug = configuration.dig(:non, :existant, :thing, safe: true)
      expect(dug).to be_instance_of(described_class)
      expect(dug).to eq({})
    end
  end

  describe "#dig!" do
    it "returns values it finds something" do
      expect(configuration.dig!(:thing, :other_thing)).to eq({third_thing: true})
    end

    it "returns nil when it can't find something" do
      expect { configuration.dig!(:non, :existant, :thing) }.to raise_error(Ravioli::KeyMissingError)
    end
  end

  describe "#fetch" do
    it "returns values it finds something" do
      expect(configuration.fetch(:thing, :other_thing) { {fourth_thing: false} }).to eq({third_thing: true})
    end

    it "returns nil when it can't find something" do
      expect(configuration.fetch(:non, :existant, :thing) { {fourth_thing: false} }).to eq({fourth_thing: false})
    end
  end

  describe "#lock!" do
    before do
      configuration.lock!
    end

    it "prevents `append` actions" do
      expect { configuration.append(foo: :bar) }.to raise_error(Ravioli::ReadOnlyError)
    end

    it "prevents direct assignment" do
      expect { configuration.foo = :bar }.to raise_error(Ravioli::ReadOnlyError)
    end

    it "prevents hash-style assigment" do
      expect { configuration[:foo] = :bar }.to raise_error(Ravioli::ReadOnlyError)
    end
  end

  describe "#safe" do
    it "returns values it finds something" do
      expect(configuration.safe(:thing, :other_thing)).to eq({third_thing: true})
    end

    it "returns a blank config file when it can't find something" do
      dug = configuration.safe(:non, :existant, :thing)
      expect(dug).to be_instance_of(described_class)
      expect(dug).to eq({})
    end
  end
end

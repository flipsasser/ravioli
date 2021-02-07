# frozen_string_literal: true

require "spec_helper"
require "ravioli/configuration"

RSpec.describe Ravioli::Configuration do
  let(:settings) { {thing: {other_thing: {third_thing: true}}} }
  let(:configuration) { described_class.new(settings) }

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
      expect(configuration.thing.other_thing.key_path).to eq(%i[thing other_thing])
    end
  end

  describe "#dig" do
    it "returns values it finds" do
      expect(configuration.dig(:thing, :other_thing)).to eq(build(third_thing: true))
    end

    it "returns nil when it can't find something" do
      expect(configuration.dig(:non, :existant, :thing)).to be_nil
    end

    it "returns a blank config file when it can't find something and is passed a truthy `safe:` keyword" do
      dug = configuration.dig(:non, :existant, :thing, safe: true)
      expect(dug).to be_instance_of(described_class)
      expect(dug).to eq(empty)
    end
  end

  describe "#dig!" do
    it "returns values it finds" do
      expect(configuration.dig!(:thing, :other_thing)).to eq(build(third_thing: true))
    end

    it "raises a KeyMissingError when it can't find something" do
      expect { configuration.dig!(:non, :existant, :thing) }.to raise_error(Ravioli::KeyMissingError)
    end
  end

  describe "#fetch" do
    it "returns values it finds" do
      expect(configuration.fetch(:thing, :other_thing) { {fourth_thing: false} }).to eq(build(third_thing: true))
    end

    it "returns the result of the fallback block when it can't find something" do
      expect(configuration.fetch(:non, :existant, :thing) { {fourth_thing: false} }).to eq({fourth_thing: false})
    end
  end

  describe "#freeze" do
    before do
      configuration.freeze
    end

    it "prevents `append` actions" do
      expect { configuration.append(foo: :bar) }.to raise_error(FrozenError)
    end

    it "prevents direct assignment" do
      expect { configuration.foo = :bar }.to raise_error(FrozenError)
    end

    it "prevents hash-style assigment" do
      expect { configuration[:foo] = :bar }.to raise_error(FrozenError)
    end
  end

  describe "#pretty_print" do
    it "delegates to the hash table" do
      expect(configuration.pretty_inspect).to eq(settings.pretty_inspect)
    end
  end

  describe "#safe" do
    it "returns values it finds" do
      expect(configuration.safe(:thing, :other_thing)).to eq(build(third_thing: true))
    end

    it "returns an empty config object when it can't find something" do
      dug = configuration.safe(:non, :existant, :thing)
      expect(dug).to be_instance_of(described_class)
      expect(dug).to eq(empty)
    end
  end

  describe "when environmental overrides are present" do
    around do |example|
      ENV["THING_OTHER_THING_THIRD_THING"] = nil
      example.run
      ENV["THING_OTHER_THING_THIRD_THING"] = nil
    end

    describe "#dig" do
      it "returns the ENV override from a root-level config" do
        expect {
          ENV["THING_OTHER_THING_THIRD_THING"] = "false"
        }.to change {
          configuration.dig(:thing, :other_thing, :third_thing)
        }.from(true).to("false")
      end

      it "returns the ENV override from a child config" do
        expect {
          ENV["THING_OTHER_THING_THIRD_THING"] = "false"
        }.to change {
          configuration.thing.dig(:other_thing, :third_thing)
        }.from(true).to("false")
      end
    end

    describe "direct accessors" do
      it "return the ENV override from the accessor" do
        expect {
          ENV["THING_OTHER_THING_THIRD_THING"] = "false"
        }.to change {
          described_class.new(settings).thing.other_thing.third_thing
        }.from(true).to("false")
      end
    end
  end
end

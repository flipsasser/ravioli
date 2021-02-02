# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ravioli::Engine" do
  describe "auto-loading" do
    it "loads up all YAML, JSON, and encrypted credentials from `config/**/*`" do
      expect(Rails.config).to eq(build(
        staging: false,
        nested: {
          things: [
            {
              whatever: false,
            },
          ],
        },
        json_test: {
          whatever: true,
          anything_else: false,
        },
        json_env_test: {
          thing: true,
          another_thing: false,
        },
        cable: {
          adapter: "test",
        },
        storage: {
          test: {
            service: "Disk",
            root: "/Users/flip/Monti/ravioli/spec/dummy/tmp/storage",
          },
          local: {
            service: "Disk",
            root: "/Users/flip/Monti/ravioli/spec/dummy/storage",
          },
        },
        yml_env_test: {
          thing: true,
          another_thing: false,
        },
        database: {
          adapter: "sqlite3",
          pool: 5,
          timeout: 5000,
          database: "db/test.sqlite3",
        },
        yml_test: {
          whatever: true,
          anything_else: false,
        },
        name: "Dummy McAppface",
        host: "http://localhost:3000/",
        secret_key_base: "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
      ))
    end
  end
end

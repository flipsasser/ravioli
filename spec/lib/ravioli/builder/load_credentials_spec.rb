# frozen_string_literal: true

require "rails_helper"
require "ravioli/builder"

RSpec.describe Ravioli::Builder, "#load_credentials" do
  let(:builder) { described_class.new(strict: false) }
  let(:configuration) { builder.build! }

  it "loads the root credentials file with a key file" do
    ENV["RAILS_MASTER_KEY"] = nil
    builder.load_credentials("credentials", key_path: "master.key", env_names: "master")
    expect(configuration).to eq(build(
      name: "Dummy McAppface",
      host: "http://localhost:3000/",
      secret_key_base: "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    ))
  end

  it "loads the root credentials file with an interpolated ENV key" do
    ENV["RAILS_MASTER_KEY"] = File.read(Rails.root.join("config", "master.key"))
    builder.load_credentials("credentials", key_path: "/nothing.key", env_names: "master")
    expect(configuration).to eq(build(
      name: "Dummy McAppface",
      host: "http://localhost:3000/",
      secret_key_base: "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    ))
  end

  it "loads the root credentials file with a full ENV key name" do
    ENV["RAILS_MASTER_KEY"] = File.read(Rails.root.join("config", "master.key"))
    builder.load_credentials("credentials", key_path: "/dev/null", env_names: "RAILS_MASTER_KEY")
    expect(configuration).to eq(build(
      name: "Dummy McAppface",
      host: "http://localhost:3000/",
      secret_key_base: "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    ))
  end

  it "doesn't load credentials without a key file or an ENV variable" do
    ENV["RAILS_MASTER_KEY"] = nil
    builder.load_credentials("credentials", key_path: "/dev/null", env_names: "nothing")
    expect(configuration).to eq(empty)
  end
end

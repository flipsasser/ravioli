# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ravioli do
  describe "auto-loading" do
    before do
      require "ravioli/auto"
    end

    it "loads up all YAML files in `config/**/*`" do
      puts App.inspect
      expect(App.test).to eq({
        thing: true,
        another_thing: false,
      })
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ravioli::Engine" do
  describe "auto-loading" do
    it "loads up all YAML, JSON, and encrypted credentials from `config/**/*`" do
      ENV["DATABASE_URL"] = "db/example.sqlite3"
      expect(Rails.config).to eq(Rails.config.class.new(
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
        reserved_names: {
          apiVersion: "cert-manager.io/v1",
               :kind=>"ClusterIssuer",
               :metadata=>{:name=>"letsencrypt"},
               :spec =>
                {:acme=>
                  {:server=>"https://acme-v02.api.letsencrypt.org/directory",
                   :privateKeySecretRef=>{:name=>"letsencrypt"},
                   :solvers=>
                    [{:http01=>
                       {:ingress=>
                         {:class=>"nginx",
                          :podTemplate=>
                           {:spec=>{:nodeSelector=>{:"kubernetes.io/os"=>"linux"}}}}}}]}},
        },

        storage: {
          test: {
            service: "Disk",
            root: Rails.root.join("tmp", "storage").to_s,
          },
          local: {
            service: "Disk",
            root: Rails.root.join("storage").to_s,
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
          url: "db/example.sqlite3",
        },
        yml_test: {
          whatever: true,
          anything_else: false,
        },
        name: "Dummy McAppface",
        host: "http://test.local",
        secret_key_base: "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
      ))
    end
  end
end

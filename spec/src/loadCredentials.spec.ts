import { expect } from "chai"
import { readFileSync } from "fs"
import "mocha"
import { resolve } from "path"

import { loadCredentials } from "../../src/loadCredentials"

describe("loadCredentials", () => {
  it("loads the root credentials file with a key file", () => {
    delete process.env.RAILS_MASTER_KEY
    expect(
      loadCredentials("spec/fixtures/dummy/config/credentials.yml.enc", {
        envKeys: ["master"],
        keyPath: "spec/fixtures/dummy/config/master.key",
      }),
    ).to.deep.eq({
      host: "http://localhost:3000/",
      name: "Dummy McAppface",
      secret_key_base:
        "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    })
  })

  it("loads the root credentials file with an interpolated ENV key", () => {
    process.env.RAILS_MASTER_KEY = readFileSync(
      resolve(process.cwd(), "spec/fixtures/dummy/config/master.key"),
    ).toString()
    expect(
      loadCredentials("spec/fixtures/dummy/config/credentials.yml.enc", {
        envKeys: ["master"],
        keyPath: "/nothing.key",
      }),
    ).to.deep.eq({
      host: "http://localhost:3000/",
      name: "Dummy McAppface",
      secret_key_base:
        "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    })
  })

  it("loads the root credentials file with a full ENV key name", () => {
    process.env.RAILS_MASTER_KEY = readFileSync(
      resolve(process.cwd(), "spec/fixtures/dummy/config/master.key"),
    ).toString()
    expect(
      loadCredentials("spec/fixtures/dummy/config/credentials.yml.enc", {
        envKeys: ["RAILS_MASTER_KEY"],
        keyPath: "/dev/null",
      }),
    ).to.deep.eq({
      host: "http://localhost:3000/",
      name: "Dummy McAppface",
      secret_key_base:
        "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
    })
  })

  it("doesn't load credentials without a key file or an ENV variable", () => {
    delete process.env.RAILS_MASTER_KEY
    process.env.RAILS_MASTER_KEY = readFileSync(
      resolve(process.cwd(), "spec/fixtures/dummy/config/master.key"),
    ).toString()
    expect(
      loadCredentials("spec/fixtures/dummy/config/credentials.yml.enc", {
        envKeys: ["nothing"],
        keyPath: "/dev/null",
      }),
    ).to.deep.eq({})
  })
})

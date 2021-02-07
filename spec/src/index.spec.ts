import chai, { expect } from "chai"
import exclude from "chai-exclude"

import "mocha"
import config from "../../src"
import { configuration } from "../../src/configuration"

chai.use(exclude)

describe("config", () => {
  it("is a function", () => {
    expect(typeof config).to.eq("function")
  })

  it("loads a default config", () => {
    expect(config())
      .excludingEvery(["require", "safe"])
      .to.deep.eq(
        configuration({
          cable: {
            adapter: "test",
          },
          database: {
            adapter: "sqlite3",
            database: "db/test.sqlite3",
            pool: '<%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>',
            timeout: 5000,
          },
          host: "http://test.local",
          jsonEnvTest: {
            anotherThing: false,
            thing: true,
          },
          jsonTest: {
            anythingElse: false,
            whatever: true,
          },
          name: "Dummy McAppface",
          nested: {
            things: [
              {
                whatever: false,
              },
            ],
          },
          secretKeyBase:
            "b097c3056fdf2dc7444172368fc94905c626e7d534fb684d3148672a67d1c706cb7f0c70354c3d1c66a3214318c523204d9903172c72daf846f5bdedfc551b52",
          staging: false,
          storage: {
            local: {
              root: '<%= Rails.root.join("storage") %>',
              service: "Disk",
            },
            test: {
              root: '<%= Rails.root.join("tmp/storage") %>',
              service: "Disk",
            },
          },
          ymlEnvTest: {
            anotherThing: false,
            thing: true,
          },
          ymlTest: {
            anythingElse: false,
            whatever: true,
          },
        })(),
      )
  })
})

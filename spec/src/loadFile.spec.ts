import { expect, use } from "chai"
import "mocha"
import { spy } from "sinon"
import sinonChai from "sinon-chai"

import { ParseError } from "../../src/errors"
import { loadFile } from "../../src/loadFile"

use(sinonChai)
describe("loadFile", () => {
  it("loads JSON configuration files", () => {
    expect(loadFile("spec/fixtures/dummy/config/json_test.json")).to.deep.eq({
      // Important note: loadFile does NOT convert keys to camel case; this happens at the configuration level!
      json_test: {
        anythingElse: false,
        whatever: true,
      },
    })
  })

  it("loads YAML configuration files", () => {
    expect(loadFile("spec/fixtures/dummy/config/yml_test.yml")).to.deep.eq({
      yml_test: {
        anything_else: false,
        whatever: true,
      },
    })
  })

  it("load nested files and renames them if they're named 'config'", () => {
    expect(loadFile("spec/fixtures/dummy/config/nested/config.json")).to.deep.eq({
      nested: {
        things: [
          {
            whatever: false,
          },
        ],
      },
    })
  })

  it("loads and merges environment-specific configuration files", () => {
    expect(loadFile("spec/fixtures/dummy/config/json_env_test.json")).to.deep.eq({
      json_env_test: {
        anotherThing: false,
        thing: true,
      },
    })
  })

  context("when errors occur", () => {
    beforeEach(() => {
      spy(console, "error")
    })

    afterEach(() => {
      console.error.restore()
    })

    it("logs an error when it can't find a file", () => {
      loadFile("non/existant/file")
      expect(console.error).to.be.called
    })

    it("throws an error when it doesn't know how to load a file", () => {
      loadFile("config/puma.rb")
      expect(console.error).to.be.called
    })
  })
})

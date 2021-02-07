import { expect } from "chai"
import "mocha"

import { ParseError } from "../../src/errors"
import { loadConfigurationFile } from "../../src/loadConfigurationFile"

describe("loadConfigurationFile", () => {
  it("loads JSON configuration files", () => {
    expect(loadConfigurationFile("spec/dummy/config/json_test.json")).to.deep.eq({
      // Important note: loadConfigurationFile does NOT convert keys to camel case; this happens at the configuration level!
      json_test: {
        anythingElse: false,
        whatever: true,
      },
    })
  })

  it("loads YAML configuration files", () => {
    expect(loadConfigurationFile("spec/dummy/config/yml_test.yml")).to.deep.eq({
      yml_test: {
        anything_else: false,
        whatever: true,
      },
    })
  })

  it("load nested files and renames them if they're named 'config'", () => {
    expect(loadConfigurationFile("spec/dummy/config/nested/config.json")).to.deep.eq({
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
    expect(loadConfigurationFile("spec/dummy/config/json_env_test.json")).to.deep.eq({
      json_env_test: {
        anotherThing: false,
        thing: true,
      },
    })
  })

  it("throws an error when it can't find a file", () => {
    expect(() => loadConfigurationFile("non/existant/file")).to.throw("ENOENT")
  })

  it("throws an error when it doesn't know how to load a file", () => {
    expect(() => loadConfigurationFile("config/puma.rb")).to.throw(ParseError)
  })
})

import { expect } from "chai"
import "mocha"

import { configuration } from "../../src/configuration"
import { KeyMissingError } from "../../src/errors"

const settings = { thing: { otherThing: { thirdThing: true } } }
const config = configuration(settings)

describe("configuration()", () => {
  describe("fetching values by keypath arrays", () => {
    it("returns values it finds", () => {
      expect(config("thing", "otherThing", "thirdThing")).to.eq(true)
    })

    it("returns values by keypath string", () => {
      expect(config("thing", "otherThing.thirdThing")).to.eq(true)
    })

    it("returns undefined when it can't find something", () => {
      expect(config("non", "existant", "thing")).to.be.undefined
    })
  })

  describe("requiring values with `require`", () => {
    it("returns values it finds", () => {
      expect(config.require("thing", "otherThing", "thirdThing")).to.eq(true)
    })

    it("throws a KeyMissingError when it can't find something", () => {
      expect(() => config.require("non", "existant", "thing")).to.throw(KeyMissingError)
    })
  })

  describe("providing fallback values", () => {
    it("returns values it finds", () => {
      expect(config("thing", "otherThing", "thirdThing", () => false)).to.eq(true)
    })

    it("returns the fallback value when it can't find something", () => {
      expect(config("non", "existant", "thing", () => false)).to.eq(false)
    })
  })

  describe("when environmental overrides are present", () => {
    it("returns the ENV override from a root-level config", () => {
      expect(config("thing.otherThing.thirdThing")).to.eq(true)
      process.env.THING_OTHER_THING_THIRD_THING = "false"
      expect(config("thing.otherThing.thirdThing")).to.eq("false")
      delete process.env.THING_OTHER_THING_THIRD_THING
    })

    it("returns the ENV override from a child config", () => {
      process.env.THING_OTHER_THING_THIRD_THING = "false"
      expect(configuration(settings)("thing.otherThing").thirdThing).to.eq("false")
      delete process.env.THING_OTHER_THING_THIRD_THING
    })
  })
})

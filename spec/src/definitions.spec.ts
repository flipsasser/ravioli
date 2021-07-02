import { expect } from "chai"
import "mocha"

import { configuration, snakeCase } from "../../src/configuration"
import { generateDefinitions } from "../../src/definitions"

const settings = { thing: { otherThing: { thirdThing: true } } }
const config = configuration(settings)

describe("definitions()", () => {
  it("returns CONSTANTIZED_STYLE_JSON_ESCAPES", () => {
    expect(generateDefinitions(config)).to.deep.eq({
      THING_OTHER_THING_THIRD_THING: "true",
    })
  })

  it("accepts a prefix", () => {
    expect(generateDefinitions(config, { prefix: "process.env." })).to.deep.eq({
      "process.env.THING_OTHER_THING_THIRD_THING": "true",
    })
  })

  it("supports overriding key transforms and separators", () => {
    expect(
      generateDefinitions(config, {
        keyTransform: input => snakeCase(input).replace(/_/g, "-"),
        separator: "-",
      }),
    ).to.deep.eq({
      "thing-other-thing-third-thing": "true",
    })
  })

  it("pulls out environment overrides just like anything else", () => {
    process.env.THING_OTHER_THING_THIRD_THING = "false"
    expect(generateDefinitions(configuration(settings))).to.deep.eq({
      THING_OTHER_THING_THIRD_THING: '"false"',
    })
    delete process.env.THING_OTHER_THING_THIRD_THING
  })
})

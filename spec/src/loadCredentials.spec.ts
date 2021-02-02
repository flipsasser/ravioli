import { expect } from "chai"
import "mocha"

import { credentials } from "../../src"

describe("loadCredentials", () => {
  it("loads encrypted credentials files", () => {
    expect(credentials).to.eql(false)
  })
})

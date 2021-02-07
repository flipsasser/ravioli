import { expect } from "chai"
import "mocha"
import { join, resolve } from "path"

import { resolveConfigFilePath } from "../../src/resolveConfigFilePath"

describe("resolveConfigFilePath", () => {
  it("resolves files given a name with no extension or sub-folder", () => {
    expect(resolveConfigFilePath("test")).to.eq(resolve(process.cwd(), join("config", "test.json")))
  })

  it("resolves files given a name with an extension", () => {
    expect(resolveConfigFilePath("test.yml")).to.eq(
      resolve(process.cwd(), join("config", "test.yml")),
    )
  })

  it("resolves files given a name with a subfolder", () => {
    expect(resolveConfigFilePath("test/nothing.json")).to.eq(
      resolve(process.cwd(), join("test", "nothing.json")),
    )
  })

  it("resolves files given a full path", () => {
    expect(resolveConfigFilePath(resolve(process.cwd(), "full/path.key"))).to.eq(
      resolve(process.cwd(), join("full", "path.key")),
    )
  })
})

import { expect } from "chai"
import "mocha"
import { join, resolve } from "path"

import { getProjectRoot } from "../../src/getProjectRoot"

describe("getProjectRoot", () => {
  context("outside of a 'workspaces' context", () => {
    it("returns the CWD", () => {
      expect(getProjectRoot()).to.eq(process.cwd())
    })
  })

  context("in workspace", () => {
    it("returns the root dummy app path", () => {
      const cwd = process.cwd()
      try {
        process.chdir("spec/fixtures/dummy/client")
        expect(getProjectRoot()).to.eq(resolve(cwd, join("spec", "fixtures")))
      } finally {
        process.chdir(cwd)
      }
    })
  })
})

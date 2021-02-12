import { existsSync } from "fs"
import { extname, join, resolve, sep } from "path"

import { getProjectRoot } from "./getProjectRoot"

interface ResolveOptions {
  extnames?: string | string[]
  root?: string
}
const defaultExtnames = ["json", "yml", "yaml"]
export function resolveConfigFilePath(
  basePath: string,
  { extnames = defaultExtnames, root = getProjectRoot() }: ResolveOptions = {},
): string {
  if (!Array.isArray(extnames)) {
    extnames = [extnames]
  }

  if (!new RegExp(`\\${sep}`).test(basePath)) {
    basePath = join("config", basePath)
  }
  const path = resolve(root, basePath)
  if (extname(path) === "") {
    for (const extension of extnames) {
      if (existsSync(`${path}.${extension}`)) {
        return `${path}.${extension}`
      }
    }

    return `${path}.${extnames[0]}`
  }

  return path
}

import { existsSync } from "fs"
import { extname, join, resolve, sep } from "path"

const defaultExtnames = ["yml", "yaml", "json"]
export function resolveConfigFilePath(basePath: string, extnames = defaultExtnames): string {
  if (!new RegExp(`\\${sep}`).test(basePath)) {
    basePath = join("config", basePath)
  }
  const path = resolve(process.cwd(), basePath)

  if (extname(path) === "") {
    for (const extension of extnames) {
      if (existsSync(`${path}.${extension}`)) {
        return `${path}.${extension}`
      }
    }

    console.warn(
      "Could not automatically resolve path",
      basePath,
      "with any of the following extensions:",
      extnames.join(", "),
    )
    return `${path}.json`
  }

  return path
}

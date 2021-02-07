import { existsSync } from "fs"
import { extname, join, resolve, sep } from "path"

const defaultExtnames = ["json", "yml", "yaml"]
export function resolveConfigFilePath(
  basePath: string,
  extnames: string | string[] = defaultExtnames,
): string {
  if (!Array.isArray(extnames)) {
    extnames = [extnames]
  }

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
      `(${path}) with any of the following extensions:`,
      extnames.join(", "),
    )
    return `${path}.${extnames[0]}`
  }

  return path
}

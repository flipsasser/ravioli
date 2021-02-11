import { existsSync, readFileSync } from "fs"
import { dirname, extname, join, normalize, relative, resolve, sep } from "path"

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

let projectRoot: string
export function getProjectRoot(): string {
  if (projectRoot) {
    return projectRoot
  }

  const initial = process.cwd()
  let previous = null
  let current = normalize(initial)

  do {
    const pkg = readPackageJSON(current)
    if (pkg?.workspaces) {
      const relativePath = relative(current, initial)

      return relativePath === "" || pkg.workspaces.includes(relativePath) ? current : initial
    }

    previous = current
    current = dirname(current)
  } while (current !== previous)

  return initial
}

function readPackageJSON(path: string): any {
  const file = join(path, "package.json")
  if (existsSync(file)) {
    return JSON.parse(readFileSync(file, "utf8"))
  }

  return null
}

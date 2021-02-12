import { existsSync, readFileSync } from "fs"
import { dirname, join, normalize, relative, resolve } from "path"

export function getProjectRoot(): string {
  const initial = normalize(process.cwd())
  let previous = null
  let current = initial

  do {
    const pkg = readPackageJSON(current)
    const workspaces = pkg?.workspaces
    if (Array.isArray(workspaces)) {
      const relativePath = relative(current, initial)

      // The current package.json contains the intial path as a workspace *if* it's the root project
      // with workspaces already (aka relativePath is a blank string because they're the same) OR if
      // it defines a workspace that, when converted to a full path, is equal to our initial path
      if (
        relativePath === "" ||
        workspaces.some((workspace: string) => {
          const workspacePath = resolve(current, workspace)

          return relative(current, workspacePath) == relativePath
        })
      ) {
        return current
      }
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

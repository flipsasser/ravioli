import deepmerge from "deepmerge"
import { readFileSync } from "fs"
import { basename, dirname, extname, sep } from "path"

import { ConfigurationData } from "./configuration"
import { ParseError } from "./errors"
import { parseYAML } from "./parseYAML"
import { resolveConfigFilePath } from "./resolveConfigFilePath"

const envKeys = new Set(["default", "development", "production", "shared", "staging", "test"])
export function loadFile(path: string, configuration?: ConfigurationData): any {
  try {
    path = resolveConfigFilePath(path)

    const extension = extname(path)
    let config: any
    switch (extension.toLowerCase()) {
      case ".json":
        config = parseJSONConfigurationFile(path)
        break
      case ".yml":
      case ".yaml":
        config = parseYAMLConfigurationFile(path)
        break
      default:
        throw new ParseError(`Ravioli doesn't know how to parse ${path}`)
    }

    let name = basename(path, extension)
    if (name.toLowerCase() === "config") {
      name = dirname(path).split(sep).pop()
    }

    // Check if the config hash is keyed by environment
    const keys = Object.keys(config)
    if (keys.every(key => envKeys.has(key))) {
      const environments = ["shared", process.env.NODE_ENV || "development"]
      if (configuration?.staging) {
        environments.push("staging")
      }

      return {
        [name]: environments.reduce(
          (finalConfig, environment) => deepmerge(finalConfig, config[environment] || {}),
          {},
        ),
      }
    }

    return { [name]: config }
  } catch (error) {
    console.error("Could not parse file at ", path, error)
    return {}
  }
}

function parseJSONConfigurationFile(path: string) {
  return JSON.parse(readFileSync(path, "utf8"))
}

function parseYAMLConfigurationFile(path: string) {
  return parseYAML(readFileSync(path).toString())
}

import { KeyMissingError } from "./errors"

export interface ConfigurationData {
  [key: string]: ConfigurationData | any
}
type ConfigFn = (...args: any[]) => any
type FallbackFn = () => any
export type Arg = string | FallbackFn
interface ConfigAccessors {
  require(...args: any[]): any
  safe(...args: any[]): any
}

export type Configuration = ConfigAccessors & ConfigurationData & ConfigFn

export function configuration(
  initialConfig: ConfigurationData | (() => ConfigurationData) = {},
): Configuration {
  let data: ConfigurationData
  let keyPath: string[]

  if (typeof initialConfig === "object") {
    keyPath = initialConfig._keyPath || []
    delete initialConfig._keyPath
    data = {}
    append(initialConfig, data, keyPath)
  } else {
    keyPath = []
  }

  function get(...args: Arg[]): any {
    if (!data && typeof initialConfig === "function") {
      data = {}
      append(initialConfig(), data, keyPath)
    }

    if (args.length === 0) {
      return Object.assign({}, data)
    }

    const fallback = extractFallback(args)
    const keys: string[] = args.reduce((all, arg) => all.concat(arg.toString().split(".")), [])

    return envValueForKeyPath(keyPath.concat(keys), () => {
      let value = data[camelize(keys.shift())]
      for (const key of keys) {
        if (typeof value === "object" || typeof value === "function") {
          value = value[camelize(key)]
        } else {
          value = undefined
          break
        }
      }

      if (fallback && (value === null || typeof value === "undefined")) {
        value = fallback()
      }

      return value
    })
  }

  const accessors = {
    require: (...args: Arg[]): any => {
      // Discard any default value function from the args
      extractFallback(args)

      // Add our own default value function, which will throw the error when called
      args.push(() => {
        throw new KeyMissingError(
          `Could not find configuration value at key path [${args
            .map(arg => JSON.stringify(arg))
            .join(", ")}]`,
        )
      })
      return get.apply(this, args)
    },
    safe: (...args: Arg[]): any => {
      return get.apply(this, args) || configuration({})
    },
  }

  if (data) {
    const { name: _, displayName: __, ...dataWithoutReservedProperties } = data
    return Object.assign(get, accessors, dataWithoutReservedProperties)
  } else {
    return Object.assign(get, accessors)
  }
}

function append(config: any, result: ConfigurationData, keyPath: string[]) {
  for (let key in config) {
    if (config.hasOwnProperty(key)) {
      const value: any = config[key]
      key = camelize(key)
      result[key] = cast(keyPath.concat([key]), value)
    }
  }
}

function camelize(input: string) {
  return input.replace(/[^a-z0-9](\w)/gi, (_, letter) => letter.toUpperCase())
}

function cast(keyPath: string[], value: any): any {
  const isObject = typeof value == "object"
  const isArray = isObject && Array.isArray(value)
  if (isObject && !isArray) {
    return configuration(Object.assign({}, value, { _keyPath: keyPath }))
  } else {
    return envValueForKeyPath(keyPath, () => {
      if (isArray) {
        return (value as any[]).map((item, index) => cast(keyPath.concat([index.toString()]), item))
      } else {
        return value
      }
    })
  }
}

function envValueForKeyPath(keyPath: string[], fallback: FallbackFn): any {
  const envValue = process.env[keyPath.map(snakeCase).join("_").toUpperCase()]
  if (envValue !== null && typeof envValue !== "undefined") {
    return envValue
  } else {
    return fallback()
  }
}

function extractFallback(args: Arg[]): FallbackFn {
  if (typeof args[args.length - 1] === "function") {
    return args.pop() as FallbackFn
  }
}

export function snakeCase(input: string): string {
  if (!input) {
    return ""
  }

  return String(input)
    .replace(/^[^A-Za-z0-9]*|[^A-Za-z0-9]*$/g, "")
    .replace(/([a-z])([A-Z])/g, (_, a, b) => a + "_" + b.toLowerCase())
    .replace(/[^A-Za-z0-9]+|_+/g, "_")
    .toLowerCase()
}

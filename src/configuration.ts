import { KeyMissingError } from "./errors"

export interface ConfigurationData {
  [key: string]: ConfigurationData | any
}
type ConfigFn = (...args: any[]) => any
type FallbackFn = () => any
export type Arg = string | FallbackFn

export type Configuration = {
  require(...args: any[]): any
  safe(...args: any[]): any
} & ConfigurationData &
  ConfigFn

export function configuration(initialConfig: any = {}): Configuration {
  const data: ConfigurationData = {}
  const keyPath: string[] = initialConfig._keyPath || []
  delete initialConfig._keyPath

  if (initialConfig) {
    for (let key in initialConfig) {
      if (initialConfig.hasOwnProperty(key)) {
        const value: any = initialConfig[key]
        key = camelize(key)
        data[key] = cast(keyPath.concat([key]), value)
      }
    }
  }

  function get(...args: Arg[]): any {
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

  const { name: _, displayName: __, ...dataWithoutReservedProperties } = data

  return Object.assign(
    get,
    {
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
    },
    dataWithoutReservedProperties,
  )
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

import { Configuration, snakeCase } from "./configuration"

interface Definition {
  [key: string]: any
}

type KeyTransform = (key: string) => string
interface Options {
  keyTransform?: KeyTransform | false
  prefix?: string
  separator?: string | false
  valueTransform?: (value: any) => any
}

const defaultTransform: KeyTransform = (input: string) => snakeCase(input).toUpperCase()

export function generateDefinitions(
  config: Configuration,
  {
    prefix,
    keyTransform = defaultTransform,
    separator = "_",
    valueTransform = JSON.stringify,
  }: Options = {},
): Definition {
  return convertNestedObjectsToKeypaths(config, { keyTransform, prefix, separator, valueTransform })
}

interface ConvertOptions extends Options {
  keypath?: string
}

function convertNestedObjectsToKeypaths(
  config: Configuration,
  { keypath, ...options }: ConvertOptions,
) {
  let result: Definition = {}
  const data = config()
  for (const key in data) {
    const value = data[key]
    if (typeof value === "function") {
      result = Object.assign(
        {},
        result,
        convertNestedObjectsToKeypaths(config(key), {
          keypath: combineKeys([keypath, key], options),
          ...options,
        }),
      )
    } else {
      let finalKey = combineKeys([keypath, key], options)
      if (options.prefix) {
        finalKey = `${options.prefix}${finalKey}`
      }
      result[finalKey] = options.valueTransform(value)
    }
  }
  return result
}

function combineKeys(keys: string[], { keyTransform, separator }: ConvertOptions) {
  return keys
    .reduce((combined, key) => {
      if (key) {
        if (keyTransform) {
          combined.push(keyTransform(key))
        } else {
          combined.push(key)
        }
      }
      return combined
    }, [])
    .join(separator || "")
}

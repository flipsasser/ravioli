import { createCipheriv } from "crypto"
import deepmerge from "deepmerge"
import { existsSync, readFileSync } from "fs"
import { load as loadYAML } from "js-yaml"
import { resolve } from "path"
import YAML from "yaml"

interface LoadOptions {
  envKey?: string
  keyPath?: string
}

function resolveCredentialPath(path: string) {
  return resolve(process.cwd(), path)
}

function loadCredentials(file: string, options: LoadOptions): any {
  // Ensure the file exists and parse it if we can
  const path = resolveCredentialPath(file)
  if (!existsSync(path)) {
    return {}
  }

  // Determine which key to use - either an ENV variable or a file - and generate a secret from it
  const { envKey, keyPath } = options
  let key = envKey ? process.env[envKey] || process.env[`RAILS_${envKey}`] : null
  if (!key) {
    const keyFile = resolveCredentialPath(keyPath)
    if (!existsSync(keyFile)) {
      return {}
    }

    key = readFileSync(keyFile, "ascii")
  }

  const secret = Buffer.from(key, "hex")

  // Read the encrypted file and split it into its constituent parts
  const contents = readFileSync(path, "ascii")
  const [data, iv, _] = contents.split("--").map(part => Buffer.from(part, "base64"))

  // Decrypt the file
  const cipher = createCipheriv("aes-128-gcm", secret, iv)
  let decrypted = Buffer.concat([cipher.update(data), cipher.final()])

  // Unmarshal a marshal'd Ruby string. The delimiter of a marshal'd string is a single '"'
  // character, so we pull everything between those two
  decrypted = decrypted.slice(decrypted.indexOf('"') + 1)
  const readByte = () => {
    const nextByte = decrypted[0]
    decrypted = decrypted.slice(1)
    return nextByte
  }

  // The next byte will indicate the length of the subsequent string
  const pointer = readByte()

  // If it's between 4 and 127, that's the length of the substring - otherwise it indicates the
  // number of bytes to
  // consume in calculating the actual length
  const consume = pointer >= 1 && pointer <= 3 ? pointer : 0
  let length = consume > 0 ? 0 : pointer

  // If it's between 1 and 3 (inclusive), we consume that number of subsequent bytes and sum them to
  // determine string length
  for (let i = 0; i < consume; i++) {
    length = length | (readByte() << (8 * i))
  }
  decrypted = decrypted.slice(0, length)

  // Neato - parse the YAML
  return YAML.parse(decrypted.toString()) || {}
}

interface BuildCombinatorOptions {
  transformKey?: (keys: string[]) => string
  transformObject?: (parent: any, child: any, keys: string[]) => any
  transformValue?: (value: any, keys: string[]) => any
}

type Combinator<T = any> = (object: any, key?: string[]) => T

function buildCombinator<T = any>({
  transformKey = keys => keys[keys.length - 1],
  transformObject = object => object, // Do nothing to child objects
  transformValue = value => value,
}: BuildCombinatorOptions = {}): Combinator<T> {
  const combinator = (object: any, keys: string[] = []): T => {
    let combinedObject: any = {}
    for (const key in object) {
      if (object.hasOwnProperty(key)) {
        const value = object[key]
        const newKeys = [...keys, key]

        switch (typeof value) {
          case "object":
            combinedObject = transformObject(combinedObject, value, newKeys)
            break
          default:
            const newKey = transformKey(newKeys)
            combinedObject[newKey] = transformValue(value, newKeys)
        }
      }
    }

    return combinedObject
  }

  return combinator
}

const combineCredentialsWithEnv = buildCombinator({
  transformObject: (parent, child, keys) => {
    parent[keys[keys.length - 1]] = combineCredentialsWithEnv(child, keys)
    return parent
  },
  transformValue: (value, keys) => process.env[keys.join("_").toUpperCase()] || value,
})

const aliasCredentials: Combinator = buildCombinator({
  transformKey: keys => `process.env.${keys.join("_").toUpperCase()}`,
  transformObject: (parent, child, keys) => ({
    ...parent,
    ...aliasCredentials(child, keys),
  }),
  transformValue: value => JSON.stringify(value),
})

const rootCredentials = loadCredentials("config/credentials.yml.enc", {
  envKey: "ROOT_KEY",
  keyPath: "config/master.key",
})

const env = process.env.NODE_ENV || "development"
const envCredentials = loadCredentials(`config/credentials/${env}.yml.enc`, {
  envKey: "MASTER_KEY",
  keyPath: `config/credentials/${env}.key`,
})

const combinedCredentials = deepmerge<any>(rootCredentials, envCredentials)
export const credentials: any = combineCredentialsWithEnv(combinedCredentials)
export const aliasedCredentials = aliasCredentials(credentials)

export function getCredential(...keyPath: string[]): void {
  let result: any = credentials
  for (const key of keyPath) {
    if (!result || typeof result !== "object") {
      return null
    }

    result = result[key]
  }

  return result
}

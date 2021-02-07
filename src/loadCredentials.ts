import { createCipheriv } from "crypto"
import { existsSync, readFileSync } from "fs"

import { parseYAML } from "./parseYAML"
import { resolveConfigFilePath } from "./resolveConfigFilePath"

interface LoadCredentialsOptions {
  envKey?: string
  keyPath?: string
}

export function loadCredentials(path: string, options?: LoadCredentialsOptions): any {
  path = resolveConfigFilePath(path, "yml.enc")

  // Ensure the file exists! This is meant to support a world in which people don't opt-in to
  // encrypted credentials.
  if (!existsSync(path)) {
    return {}
  }

  // Determine which key to use - either an ENV variable or a file - and generate a secret from it
  const contents = readFileSync(path, "ascii")
  const [data, iv, _] = contents.split("--").map(part => Buffer.from(part, "base64"))

  let { envKey, keyPath } = options
  if (envKey && !/_/.test(envKey)) {
    envKey = `RAILS_${envKey.toUpperCase()}_KEY`
  }

  let key = envKey && process.env[envKey]
  if (!key) {
    const keyFile = resolveConfigFilePath(keyPath, "key")
    if (!existsSync(keyFile)) {
      return {}
    }

    key = readFileSync(keyFile, "ascii")
  }

  // Decrypt the file
  const secret = Buffer.from(key, "hex")
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
  return parseYAML(decrypted.toString()) || {}
}

import { createDecipheriv } from "crypto"
import { existsSync, readFileSync } from "fs"

import { parseYAML } from "./parseYAML"
import { resolveConfigFilePath } from "./resolveConfigFilePath"

interface LoadCredentialsOptions {
  envKeys?: string[]
  keyPath?: string
}

export function loadCredentials(path: string, options?: LoadCredentialsOptions): any {
  path = resolveConfigFilePath(path, { extnames: "yml.enc" })

  // Ensure the file exists! This is meant to support a world in which people don't opt-in to
  // encrypted credentials.
  if (!existsSync(path)) {
    return {}
  }
  const contents = readFileSync(path, "ascii")

  // Determine which key to use - either an ENV variable or a file - and generate a secret from it
  let decrypted: Buffer
  const { envKeys, keyPath } = options
  for (let key of envKeys) {
    key = keyFromEnv(key)
    if (key) {
      decrypted = tryDecipher(contents, key)
      if (decrypted) {
        break
      }
    }
  }

  if (!decrypted) {
    const keyFile = resolveConfigFilePath(keyPath, { extnames: "key" })
    if (existsSync(keyFile)) {
      decrypted = tryDecipher(contents, readFileSync(keyFile, "ascii"))
    }
  }

  if (!decrypted) {
    return {}
  }

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

function keyFromEnv(key: string): string {
  if (!key) {
    return
  }

  return process.env[!/RAILS_/i.test(key) ? `RAILS_${key.toUpperCase()}_KEY` : key]
}

function tryDecipher(contents: string, key: string): Buffer {
  // Load and decrypt the file using our key
  const [data, iv, authTag] = contents.split("--").map(part => Buffer.from(part, "base64"))

  const secret = Buffer.from(key, "hex")
  const decipher = createDecipheriv("aes-128-gcm", secret, iv)
  decipher.setAuthTag(authTag)

  try {
    const result = Buffer.concat([decipher.update(data), decipher.final()])
    return result
  } catch (e) {
    return null
  }
}

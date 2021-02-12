import deepmerge from "deepmerge"
import { sync as glob } from "glob"
import { join } from "path"

import { configuration } from "./configuration"
import { getProjectRoot } from "./getProjectRoot"
import { loadConfigurationFile } from "./loadConfigurationFile"
import { loadCredentials } from "./loadCredentials"

// eslint-disable-next-line import/no-default-export
export default configuration(() => {
  const splat = "{[!locales]**/*,*}.{json,yaml,yml}"
  // Set up some defaults with a staging flag
  let config: any = {
    staging: process.env.NODE_ENV == "production" && !!process.env.STAGING,
  }

  // Load all config files in the `config/` directory we can
  const root = getProjectRoot()
  let files: string[] = glob(join(root, "config", splat))
  if (root !== process.cwd()) {
    files = files.concat(glob(join(process.cwd(), "config", splat)))
  }

  files.forEach(file => {
    config = deepmerge(config, loadConfigurationFile(file, config))
  })

  // Load all the credentials files we can
  config = deepmerge(
    config,
    loadCredentials("config/credentials", {
      envKey: "base",
      keyPath: "config/master.key",
    }),
  )

  const env = process.env.NODE_ENV || "development"
  config = deepmerge(
    config,
    loadCredentials(`config/credentials/${env}`, {
      envKey: "master",
      keyPath: `config/credentials/${env}.key`,
    }),
  )

  if (config.staging) {
    config = deepmerge(
      config,
      loadCredentials("config/credentials/staging", {
        envKey: "staging",
        keyPath: "config/credentials/staging.key",
      }),
    )
  }

  return config
})

// Export the other pieces of the package
export * from "./configuration"
export * from "./errors"
export * from "./loadConfigurationFile"
export * from "./loadCredentials"
export * from "./resolveConfigFilePath"

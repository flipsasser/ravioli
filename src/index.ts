import deepmerge from "deepmerge"
import { sync as glob } from "glob"
import { join, resolve } from "path"

import { Arg, Configuration, configuration } from "./configuration"
import { loadConfigurationFile } from "./loadConfigurationFile"
import { loadCredentials } from "./loadCredentials"

// Export a default config that will bootstrap itself when referenced; it does nothing unless it is
// used
let defaultConfiguration: Configuration

// eslint-disable-next-line import/no-default-export
export default function (...args: Arg[]): any {
  if (!defaultConfiguration) {
    // Set up some defaults with a staging flag
    let config: any = {
      staging: process.env.NODE_ENV == "production" && !!process.env.STAGING,
    }

    // Load all config files in the `config/` directory we can
    const configDir = resolve(process.cwd(), "config")
    const files = glob(join(configDir, "{[!locales]**/*,*}.{json,yaml,yml}"))
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

    // Set up a default configuration
    defaultConfiguration = configuration(config)
  }

  return defaultConfiguration.apply(this, args)
}

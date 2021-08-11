import deepmerge from "deepmerge"
import { sync as glob } from "glob"
import { join } from "path"

import { configuration } from "./configuration"
import { getProjectRoot } from "./getProjectRoot"
import { loadCredentials } from "./loadCredentials"
import { loadFile } from "./loadFile"

// eslint-disable-next-line import/no-default-export
export default configuration(() => {
  const splat = "{[!locales]**/*,*}.{json,yaml,yml}"
  // Set up some defaults with a staging flag
  const production = process.env.NODE_ENV == "production"
  let config: any = {
    staging: production && !!process.env.STAGING,
  }

  // Load all config files in the `config/` directory we can
  const root = getProjectRoot()
  let files: string[] = glob(join(root, "config", splat))
  if (root !== process.cwd()) {
    files = files.concat(glob(join(process.cwd(), "config", splat)))
  }

  files.forEach(file => {
    config = deepmerge(config, loadFile(file, config))
  })

  // Load all the credentials files we can
  config = deepmerge(
    config,
    loadCredentials("config/credentials", {
      envKeys: ["master", "root"],
      keyPath: "config/master.key",
    }),
  )

  const env = process.env.NODE_ENV || "development"
  config = deepmerge(
    config,
    loadCredentials(`config/credentials/${env}`, {
      envKeys: ["master"],
      keyPath: `config/credentials/${env}.key`,
    }),
  )

  if (config.staging) {
    config = deepmerge(
      config,
      loadCredentials("config/credentials/staging", {
        envKeys: ["staging", "master"],
        keyPath: "config/credentials/staging.key",
      }),
    )
  }

  return config
})

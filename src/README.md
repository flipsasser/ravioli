# Ravioli.js

**Grab a fork and twist your configuration spaghetti in a single, delicious dumpling!**

Ravioli combines all of your app's runtime configuration into a unified, simple interface. **It combines YAML or JSON configuration files, encrypted Rails credentials, and ENV vars into one easy-to-consume interface** so you can focus on writing code and not on where configuration comes from.

**It's as simple as this:**

```javascript
import { config } from "ravioli"
const key = config.require("thing", "api_key")
```

## Table of Contents

1. [Installation](#installation)
2. [Setup](#setup)
3. [Usage](#usage)
4. [How ENV vars work](#how-env-vars-work)
5. [License](#license)

## Installation

Install the package how you would any other package:

- Yarn: `yarn add ravioli`
- NPM: `npm install --save ravioli`
- NPX: I don't know how NPX works; I'm still using Yarn. However you would do that, I guess?

## Usage

For the following examples, we'll use the following configuration structure*:

```yaml
host: "example.com"
url: "https://www.example.com"
sender: "reply-welcome@example.com"

database:
  host: "localhost"
  port: "5432"

sendgrid:
  api_key: "12345"

sentry:
  api_key: "12345"
  environment: <%= Rails.env %>
  dsn: "https://sentry.io/whatever?api_key=12345"
```

<small>*this structure is the end result of Ravioli's loading process; it has nothing to do with filesystem organization or config file layout. We'll talk about that in a sec, so just slow your roll about loading up config files until then, my good friend.</small>

### Setup

You can use Ravioli in one of two ways. The first way is to allow it do all the configuration itself. It follows the logic in the Ruby gem identically, so if you're using both, your environments will match.

The easiest way to use it is to import the default configuration object from Ravioli, which will simply configure itself the first time you use it:

```javascript
import config from "ravioli"
console.log(config().database.host) // outputs "localhost"
```

### Accessing configuration values directly

Ravioli supports direct accessors:

```javascript
let config = require("ravioli").config()
console.log(config.host) // "example.com"
console.log(config.database.port) // "5432"
console.log(config.not.here) // Uncaught TypeError: Cannot read property 'here' of undefined
```

### Accessing configuration values safely by key path

#### Traversing the keypath with `dig`

You can traverse deeply nested config values safely with `dig`:

```javascript
config("database", "port") // "5432"
config("not", "here") // null
```

#### Providing fallback values

You can provide a sane fallback value by providing a function as the last argument when calling `config`:

```javascript
config("database", "port", () => "5678") // "5432" is returned from the config
config("not", "here", () => "PRESENT!") // "PRESENT!" is returned from the function
```

#### Requiring configuration values with `require`

If a part of your app cannot operate without a configuration value, e.g. an API key is required to make an API call, you can use `require`, which behaves identically to `dig` except it will throw a `KeyMissingError` if no value is specified:

```javascript
let key = config.require("example", "apiKey") // Uncaught KeyMissingError: Could not find configuration value at key path ["example", "apiKey"]
```

#### Ensuring you receive a config object with `safe`

If you want to make sure you are operating on a configuration object, even if it has not been set for your environment, you can use `safe`:

```javascript
config("google") // null
config.safe("google") // {}
```

Use `safe` when, for example, you don't want your code to explode because a root config key is not set. Here's an example:

```javascript
import { config } from "ravioli"
import React from "react"

const google = config.safe("google")
export const GoogleMap = (props) => (
  <React.Fragment>
    <script src={google.fetch("baseUri", () => `https://api.google.com/maps-do-stuff-cool-rights?apiKey=${google.apiKey}`)}>
    <div className="google-maps-wrapper" {...props} />
  </React>
)
```

### `ENV` variables and precedence

`ENV` variables take precedence over loaded configuration files. When examining your configuration, Ravioli checks for a capitalized `ENV` variable corresponding to the keypath you're searching. Thus `config("database", "url")` is equivalent to `process.env.DATABASE_URL || config.database?.url`.

Configuration values take precedence in the order they are applied. For example, if you load two config files defining `host`, the latest one will overwrite the earlier one's value.

## Automatic Configuration

The fastest way to use Ravioli is via automatic configuration, bootstrapping it into the `config` object exported from the package. This is the default experience when you import it either via `import config from "ravioli"` or `const config = require("ravioli")`.

The automatic configuration is equivalent to the following:

1. Load all `.yml` and `.json` files in your app's root `config/` directory EXCEPT for `config/locales/**/*.yml`
2. Load encrypted credentials files ([see Encryped Credentials" for details](#encrypted-credentials))
3. Set a `staging` flag on `config` to the default value of `process.env.NODE_ENV == "production" && !!process.env.STAGING`

It is the equivalent of manually building a configuration using lower-level Ravioli tools:

```javascript
import { addStagingFlag, loadConfigurationFile, loadCredentials } from "ravioli"

const config = loadConfigurationFile("config/app.json") // the contents of app.json wrapped in a Ravioli configuration accessor
loadCredentials(config, {key: "config/master.key", env: "RAILS_MASTER_KEY"})
addStagingFlag(config) // adds config("staging") or config.staging with a default value
```

## Manual configuration using `loadConfigurationFile`, `loadCredentials`, and `addStagingFlag`

You can manually define your configuration if you don't want the automatic configuration assumptions to step on any toes.

For the following examples, imagine a file in `config/sentry.yml`:

```yaml
development:
  dsn: "https://dev_user:pass@sentry.io/dsn/12345"
  environment: "development"

production:
  dsn: "https://prod_user:pass@sentry.io/dsn/12345"
  environment: "production"

staging:
  environment: "staging"
```

`loadConfigurationFile` returns an instance of a configuration, so simply export the result of that method:

```javascript
// config.js
import { loadConfigurationFile } from "ravioli"
const config = loadConfigurationFile("config/sentry.yml")

export { config }

// app.js
import { config } from "./config"
import Sentry from "sentry"

Sentry.init({
  apiKey: config("sentry", "apiKey")
})
```

### Loading credentials

### Loading config files


### Deploying with ENV encryption keys and automatic setup

Because Ravioli merges environment-specific credentials over top of the root credentials file, you'll need to provide encryption keys for two (or, if you have a staging setup, three) different files in ENV vars. As such, Ravioli looks for decryption keys in a fallback-specific way. Here's where it looks for each file:

<table><thead><tr><th>File</th><th>First it tries...</th><th>Then it tries...</th></tr></thead><tbody><tr><td>

`config/credentials.yml.enc`

</td><td>

`ENV["RAILS_BASE_KEY"]`

</td><td>

`ENV["RAILS_MASTER_KEY"]`

</td></tr><tr><td>

`config/credentials/production.yml.enc`

</td><td>

`ENV["RAILS_PRODUCTION_KEY"]`

</td><td>

`ENV["RAILS_MASTER_KEY"]`

</td></tr><tr><td>

`config/credentials/staging.yml.enc` (only if running on staging)

</td><td>

`ENV["RAILS_STAGING_KEY"]`

</td><td>

`ENV["RAILS_MASTER_KEY"]`

</td></tr></tbody></table>

Credentials are loaded in that order, too, so that you can have a base setup on `config/credentials.yml.enc`, overlay that with production-specific stuff from `config/credentials/production.yml.enc`, and then short-circuit or redirect some stuff in `config/credentials/staging.yml.enc` for staging environments.

## License

Ravioli is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
# Ravioli 🍝

**Grab a fork and twist all your configuration spaghetti into a single, delicious bundle!**

Ravioli combines all of your app's runtime configuration into a unified, simple interface. **It automatically loads and combines YAML config files, encrypted Rails credentials, and ENV vars** so you can focus on writing code and not on where configuration comes from.

**Ravioli turns this...**

```ruby
def do_something_with_a_remote_api
  APIClient.do_stuff(
    api_key: ENV.fetch("THING_API_KEY") { Rails.credentials.thing_api_key || raise("I need an API key for thing to work") }
  )
end
```

**...into this:**

```ruby
def do_something_with_a_remote_api
  APIClient.do_stuff(
    api_key: Config.dig!(:thing, :api_key)
  )
end
```

<!--**FYI** Ravioli is two libraries: the Rails gem and an NPM package. This README focuses on the Ruby gem. You can also [read the JavaScript documentation](blob/master/src/README.md) for specifics about how to use Ravioli either in the Rails asset pipeline or in a standalone Node server context.
-->
## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)
3. [Automatic Setup](#automatic-setup)
4. [Manual Setup](#manual-setup)
5. [How ENV vars work](#how-env-vars-work)
6. [License](#license)
<!-- 5. [JavaScript library](#javascript-library) -->

## Installation

<!--Ravioli comes as a Ruby gem or an NPM package; they work marginally differently. Let's focus on Ruby/Rails for now.
-->
1. Add `gem "ravioli"` to your `Gemfile`
2. Run `bundle`
3. Eat some pasta

## Usage

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

### Direct access

Call accessors on your app's configuration object:

```ruby
Config.sentry.dsn #=> "https://noop"
```

### Programatically using `dig` and `fetch`

`dig` works identically to [`dig`](https://ruby-doc.org/core-2.7.2/Hash.html#method-i-dig) and `fetch` works _similarly_ to [`fetch`](https://ruby-doc.org/core-2.7.2/Hash.html#method-i-fetch) on Hash objects:

```ruby
Config.dig(:sentry, :environment) #=> "development"
Config.fetch(:sentry, :no_key) { "fallback" } #=> "fallback"
```

**Note that the `fetch` implementation accepts multiple keys as arguments**, and does not provide for a `default` fallback argument - instead, the fallback _must_ appear inside of a block.

### Require a value using `dig!`

If you want to prevent code from executing absent a configuration value, use `dig!`:

```ruby
Config.dig!(:sentry, :no_key) #=> raises Config::MissingKeyError
```

### Ensuring you receive a config object with `safe` (or `dig(*keys, safe:true)`)

If you want to make sure you are operating on a configuration object, even if it has not been set for your environment, you can provide `dig` a `safe: true` flag which will effectively do the following:

```ruby
Config.dig(:google) #=> nil
Config.safe(:google) #=> Config<{}>
Config.dig(:google, safe: true) #=> Config<{}>
```

Use `safe` when, for example, you don't want your code to explode because a config key is not set. Here's an example:

```ruby
class GoogleMapsClient
  include HTTParty

  google = Config.safe(:google)
  headers "Auth-Token" => google.token, "Other-Header" => google.other_thing
  base_uri google.base_uri
end
```

## Automatic Setup

Ravioli can automatically perform all the setup you need without having to think too much. Just `require "ravioli/auto"`, for example from your `Gemfile`:

```ruby
gem "rails"
# ...
gem "ravioli", require: "ravioli/auto"
```

This bootstraps a Ravioli instance into the `Config` constant. It comes pre-loaded with everything you need:

1. `Config.staging?` #=> shorthand for `Rails.env.production? && ENV["STAGING"].present?`
2. Every `.yml` file in the `config/` directory is loaded (except for locales)
3. `config/credentials.yml.enc` is loaded (if it exists)
4. `config/credentials/#{Rails.env}.yml.enc` is loaded and merged over your configuration (if it exists)
5. `config/credentials/staging.yml.enc` is loaded and merged over your configuration (if it exists and `Config.staging?` is true)

Don't like the automatic configuration approach? Skip ahead to [manual setup](#manual-setup).

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

## Manual Setup

Let's say you don't want that automatic setup. You can create the Ravioli constant yourself manually and then load whatever you need:

`config/initializers/_ravioli.rb`

```ruby
Config = Ravioli.build do
  %i[new_relic sentry google].each do |service|
    load_config_file(service)
  end

  load_credentials # just load the base credentials file
  load_credentials("credentials/production") if Rails.env.production? # add production overrides when appropriate

  self.staging = File.exists?("./staging.txt") # technically you could do this ... I don't know why you would, but technically you could
end
```

### Loading config files

Let's imagine we have this config file:

`config/mailjet.yml`

```yaml
development:
  api_key: "NOT_USED"

test:
  api_key: "VCR"

staging:
  api_key: "12345678"

production:
  api_key: "98765432"
```

In an initializer, generate your Ravioli instance and load it up:

``config/initializers/_ravioli.rb`

```ruby
Config = Ravioli.build do
  load_config_file(:mailjet) # given a symbol, it automatically assumes you meant `config/mailjet.yml`
  load_config_file("config/mailjet") # same as above
  load_config_file("lib/mailjet/config") # looks for `Rails.root.join("lib", "mailjet", "config.yml")
end
```

### Loading Rails credentials

Imagine the following encrypted YAML files:

`rails credentials:edit`

```yaml
app:
  host: "http://localhost:3000"
```

and `rails credentials:edit --environment production`

```yaml
app:
  host: "https://www.getmonti.com/"
```

You can then load credentials like so:

``config/initializers/_ravioli.rb`

```ruby
Config = Ravioli.build do
  # Load the base credentials
  load_credentials

  # Load the env-specific credentials file. It will look for `config/credentials/#{Rails.env}.key`
  # just like Rails does. But in this case, it falls back on e.g. `ENV["PRODUCTION_KEY"]` if that
  # file is missing (as it should be when deployed to a remote server)
  load_credentials("credentials/#{Rails.env}", env_key: "#{Rails.env}_KEY")

  # Load the staging credentials. Because we did not provide an `env_key` argument, this will
  # default to looking for `ENV["RAILS_STAGING_KEY"]` or `ENV["RAILS_MASTER_KEY"]`.
  load_credentials("credentials/staging") if Rails.env.production? && srand.zero?
end
```

## How ENV vars work

Ravioli overrides loaded config or credential "key paths" with matching ENV vars. Imagine the above config setup, but run with `MAILJET_API_KEY="NEATO"` in the ENV:

```ruby
Config.mailjet.api_key #=> "NEATO"
```

### The `app` prefix and root-level ENV overrides

By default, Ravioli treats any configuration that is loaded with a root key `app` as a "root-level" ENV variable. As such, ENV variables override these *without* the `APP_` prefix. Here's an example:

`config/urls.yml`

```yaml
app:
  host: "localhost:3000"
  url: "https://localhost:3000/"
```

The ENV var overrides for these don't require the `APP_` prefix:

`HOST=localhost:8000 rails console` or `URL=http://localhost:8000 rails console` will set `Config.app.host` to `localhost:8000` or `Config.app.url` to `http://localhost:8000`.

This helps to organize root-level configuration in a nested way, which makes your config files more maintainable.

You can override the key Ravioli looks for:

```ruby
Config = Ravioli.build(root_key: :root) do
	# ... your configuration ...
end
```

You can also opt-out of this functionality when you build the Ravioli object:

```ruby
Config = Ravioli.build(root_key: false) do
  # ... your configuration ...
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

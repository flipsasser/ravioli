# Ravioli 🍝

**Grab a fork and twist your configuration spaghetti in a single, delicious dumpling!**

Ravioli combines all of your app's runtime configuration into a unified, simple interface. **It combines YAML or JSON configuration files, encrypted Rails credentials, and ENV vars into one easy-to-consume interface** so you can focus on writing code and not on where configuration comes from.

**Ravioli turns this...**

```ruby
key = ENV.fetch("THING_API_KEY") { Rails.credentials.thing&["api_key"] || raise("I need an API key for thing to work") }
```

**...into this:**

```ruby
key = Rails.config.dig!(:thing, :api_key)
```

<!--**FYI** Ravioli is two libraries: the Rails gem and an NPM package. This README focuses on the Ruby gem. You can also [read the JavaScript documentation](blob/master/src/README.md) for specifics about how to use Ravioli either in the Rails asset pipeline or in a standalone Node server context.
-->
## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)
 	- Direct accessors
 	- Safe key-path traversal
 	- `ENV` variables and precedence
3. [Automatic Configuration](#automatic-configuration)
4. [Manual Configuration](#manual-configuration)
	- [Rails.config vs. constants](#setup-in-rails-config-vs-constants)
5. [How ENV vars work](#how-env-vars-work)
6. [License](#license)
<!-- 5. [JavaScript library](#javascript-library) -->

## Installation

<!--Ravioli comes as a Ruby gem or an NPM package; they work marginally differently. Let's focus on Ruby/Rails for now.
-->
1. YOLO `gem "ravioli"` into your `Gemfile`
2. YOLO `bundle install`
3. (Optionally) YOLO an initializer: `rails generate ravioli:install` (Ravioli will do everything automatically for you if you skip this step, because I aim to *please*)

<!--### Setup in `Rails.config` vs. constants

You can choose where your Ravioli lives: under `Rails.config` (this is the default behavior), in a constant (e.g. `Config` or `App`), or somewhere else entirely (you could, for example, define a `Config` module, mix it in to your classes where it's needed, and access it via a `config` instance method).

**All of the examples in this README will use `Rails.config`.** My personal preference is to not pollute the global namespace, but your approach is entirely up to you. It's worth noting that the `Rails.config` route pretty much immediately violates the Law of Demeter, which is gross. The alternative is having a God object constant - also gross. Hopefully that helps explain why this library is so choose-your-own-adventure-y.-->

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

### Accessing configuration values directly

Ravioli objects support direct accessors:

```ruby
Rails.config.host #=> "example.com"
Rails.config.database.port #=> "5432"
Rails.config.not.here #=> NoMethodError (undefined method `here' for nil:NilClass)
```

### Accessing configuration values safely by key path

#### Traversing the keypath with `dig`

You can traverse deeply nested config values safely with `dig`:

```ruby
Rails.config.dig(:database, :port) #=> "5432"
Rails.config.dig(:not, :here) #=> nil
```

This works the same in principle as the [`dig`](https://ruby-doc.org/core-2.7.2/Hash.html#method-i-dig) method on `Hash` objects, with the added benefit of not caring about key type (both symbols and strings are accepted).

#### Providing fallback values with `fetch`

You can provide a sane fallback value using `fetch`, which works like `dig` but accepts a block:

```ruby
Rails.config.fetch(:database, :port) { "5678" } #=> "5432" is returned from the config
Rails.config.fetch(:not, :here) { "PRESENT!" } #=> "PRESENT!" is returned from the block
```

**Note that `fetch` accepts multiple keys as arguments**, and does not provide for a `default` fallback argument - instead, the fallback _must_ appear inside of a block. This is a slight difference from the [`fetch`](https://ruby-doc.org/core-2.7.2/Hash.html#method-i-fetch) method on `Hash` objects.

#### Requiring configuration values with `dig!`

If a part of your app cannot operate without a configuration value, e.g. an API key is required to make an API call, you can use `dig!`, which behaves identically to `dig` except it will raise a `KeyMissingError` if no value is specified:

```ruby
uri = URI("https://api.example.com/things/1")
request = Net::HTTP::Get.new(uri)
request["X-Example-API-Key"] = Rails.config.dig!(:example, :api_key) #=> Ravioli::KeyMissingError (could not find configuration value at key path [:example, :api_key])
```

#### Ensuring you receive a config object with `safe` (or `dig(*keys, safe: true)`)

If you want to make sure you are operating on a configuration object, even if it has not been set for your environment, you can provide `dig` a `safe: true` flag:

```ruby
Rails.config.dig(:google) #=> nil
Rails.config.safe(:google) #=> Config<{}>
Rails.config.dig(:google, safe: true) #=> Config<{}>
```

Use `safe` when, for example, you don't want your code to explode because a root config key is not set. Here's an example:

```ruby
class GoogleMapsClient
  include HTTParty

  google = Rails.config.safe(:google)
  headers "Auth-Token" => google.token, "Other-Header" => google.other_thing
  base_uri google.fetch(:base_uri) { "https://api.google.com/maps-do-stuff-cool-right" }
end
```


### `ENV` variables and precedence

`ENV` variables take precedence over loaded configuration files. When examining your configuration, Ravioli checks for a capitalized `ENV` variable corresponding to the keypath you're searching. Thus `Rails.config.dig(:database, :url)` is equivalent to `ENV.fetch("DATABASE_URL") { Rails.config.database&.url }`. 

Configuration values take precedence in the order they are applied. For example, if you load two config files defining `host`, the latest one will overwrite the earlier one's value.

<!--### Advanced configuration

#### The root key and top-level configuration

Most applications have top-level configuration, e.g. the user-facing name of the app, a host URL, etc. So while it makes sense to keep your Sendgrid credentials centralized in `Rails.config.sendgrid`, you probably don't want to access your host URL with `Rails.config.app.host` - `Rails.config.host` is preferable.

Similarly, who wants to define their `ENV` vars as, for example, `ENV['APP_HOST']`? Most folks just use `ENV['HOST']`.

In order to avoid confusion, you can define a `root_key` on your top-level configuration. By default this is `app` but it can be whatever you prefer. From that point on, accessors like `Rails.config.dig(:app, :host)` will return-->


## Automatic Configuration

The fastest way to use Ravioli is via automatic configuration, bootstrapping it into the `Rails.config` attribute. This is the default experience when you `require "ravioli"`, either explicitly through an initializer or implicitly through `gem "ravioli"` in your Gemfile.

The automatic configuration is equivalent to the following:

1. Load all `.yml` and `.json` files in `config/` EXCEPT locales
2. Load encrypted credentials files ([see Encryped Credentials" for details](#encrypted-credentials))
3. Set a `staging?` flag to `Rails.env.production? && ENV["STAGING"]`

It looks like this:

```ruby
def Rails.config
  @_ravioli_config ||= Ravioli.build { |config|
    config.auto_load_config_files
    config.auto_load_credential_files
    config[:staging?] = Rails.env.production? && ENV["STAGING"].present?
    Rails.env.class_eval "def staging?; true; end" if config.staging?
  }
end
```

## Manual configuration using `Ravioli.build`

You can manually defined your configuration in an initializer if you don't want the automatic configuration assumptions to step on any toes.

### Defining a central constant e.g. `App`

`Ravioli.build` returns an instance of a configuration.

### Loading credentials

### Loading config files

## Usage

### Manual configuration

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

Ravioli is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

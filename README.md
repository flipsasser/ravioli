# Ravioli.rb 🍝

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

**🚨 FYI:** Ravioli is two libraries: a Ruby gem (this doc), and a [JavaScript NPM package](src/README.md). The NPM docs contain specifics about how to [use Ravioli in the Rails asset pipeline](src/README.md#using-in-the-rails-asset-pipeline), in [a Node web server](src/README.md#using-in-a-server), or [bundled into a client using Webpack](src/README.md#using-with-webpack), [Rollup](src/README.md#using-with-rollup), or [whatever else](src/README.md#using-with-another-bundler).

## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)
3. [Automatic Configuration](#automatic-configuration)
4. [Manual Configuration](#manual-configuration)
5. [Deploying](#deploying)
6. [License](#license)
<!-- 5. [JavaScript library](#javascript-library) -->

## Installation

<!--Ravioli comes as a Ruby gem or an NPM package; they work marginally differently. Let's focus on Ruby/Rails for now.
-->
1. Add `gem "ravioli"` to your `Gemfile`
2. Run `bundle install`
3. Add an initializer (totally optional): `rails generate ravioli:install` - Ravioli will do **everything** automatically for you if you skip this step, because I'm here to put a little meat on your bones.

## Usage

Ravioli turns your app's configuration environment into a [PORO](http://blog.jayfields.com/2007/10/ruby-poro.html) with direct accessors and a few special methods. By *default*, it adds the method `Rails.config` that returns a Ravioli instance. You can access all of your app's configuration from there. _This is totally optional_ and you can also do everything manually, but for the sake of these initial examples, we'll use the `Rails.config` setup.

Either way, for the following examples, imagine we had the following configuration structure:*

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

<small>*this structure is the end result of Ravioli's loading process; it has nothing to do with filesystem organization or config file layout. We'll talk about that in a bit, so just slow your roll about loading up config files until then.</small>

**Got it? Good.** Let's access some configuration,

### Accessing values directly

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

**Note that `fetch` differs from the [`fetch`](https://ruby-doc.org/core-2.7.2/Hash.html#method-i-fetch) method on `Hash` objects.**  Ravioli's `fetch` accepts keys as arguments, and does not accept a `default` argument - instead, the default _must_ appear inside of a block.

#### Requiring configuration values with `dig!`

If a part of your app cannot operate without a configuration value, e.g. an API key is required to make an API call, you can use `dig!`, which behaves identically to `dig` except it will raise a `KeyMissingError` if no value is specified:

```ruby
uri = URI("https://api.example.com/things/1")
request = Net::HTTP::Get.new(uri)
request["X-Example-API-Key"] = Rails.config.dig!(:example, :api_key) #=> Ravioli::KeyMissingError (could not find configuration value at key path [:example, :api_key])
```

#### Allowing for blank values with `safe` (or `dig(*keys, safe: true)`)

As a convenience for avoiding the billion dollar mistake, you can use `safe` to ensure you're operating on a configuration object, even if it has not been set for your environment:

```ruby
Rails.config.dig(:google) #=> nil
Rails.config.safe(:google) #=> #<Ravioli::Configuration {}>
Rails.config.dig(:google, safe: true) #=> #<Ravioli::Configuration {}>
```

Use `safe` when, for example, you don't want your code to explode because a root config key is not set. Here's an example:

```ruby
class GoogleMapsClient
  include HTTParty

  config = Rails.config.safe(:google)
  headers "Auth-Token" => config.token, "Other-Header" => config.other_thing
  base_uri config.fetch(:base_uri) { "https://api.google.com/maps-do-stuff-cool-right" }
end
```

### Querying for presence

In addition to direct accessors, you can append a `?` to a method to see if a value exists. For example:

```ruby
Rails.config.database.host? #=> true
Rails.config.database.password? #=> false
```

### `ENV` variables take precedence over loaded configuration

I guess the headline is the thing: `ENV` variables take precedence over loaded configuration files. When loading or querying your configuration, Ravioli checks for a capitalized `ENV` variable corresponding to the keypath you're searching.

For example:

```env
Rails.config.dig(:database, :url)

# ...is equivalent to...

ENV.fetch("DATABASE_URL") { Rails.config.database&.url }
```

This means that you can use Ravioli instead of querying `ENV` for its keys, and it'll get you the right value every time.

## Automatic Configuration

**The fastest way to use Ravioli is via automatic configuration,** bootstrapping it into the `Rails.config` method. This is the default experience when you `require "ravioli"`, either explicitly through an initializer or implicitly through `gem "ravioli"` in your Gemfile.

**Automatic configuration takes the following steps for you:**

### 1. Adds a `staging` flag

First, Ravioli adds a `staging` flag to `Rails.config`. It defaults to `true` if:

1. `ENV["RAILS_ENV"]` is set to "production"
2. `ENV["STAGING"]` is not blank

Using [query accessors](#querying-for-presence), you can access this value as `Rails.config.staging?`.

**BUT, as I am a generous and loving man,** Ravioli will also ensure `Rails.env.staging?` returns `true` if 1 and 2 are true above:

```ruby
ENV["RAILS_ENV"] = "production"
Rails.env.staging? #=> false
Rails.env.production? #=> true

ENV["STAGING"] = "totes"
Rails.env.staging? #=> true
Rails.env.production? #=> true
```

### 2. Loads every plaintext configuration file it can find

Ravioli will traverse your `config/` directory looking for every YAML or JSON file it can find. It loads them in arbitrary order, and keys them by name. For example, with the following directory layout:

```
config/
  app.yml
  cable.yml
  database.yml
  mailjet.json
```

...the automatically loaded configuration will look like

```
# ...the contents of app.yml
cable:
  # ...the contents of cable.yml
database:
  # ...the contents of database.yml
mailjet:
  # ...the contents of mailjet.json
```

**NOTE THAT APP.YML GOT LOADED INTO THE ROOT OF THE CONFIGURATION!** This is because the automatic loading system assumes you want some configuration values that aren't nested. It effectively calls [`load_file(filename, key: File.basename(filename) != "app")`](#load_file), which ensures that, for example, the values in `config/mailjet.json` get loaded under `Rails.config.mailjet` while the valuaes in `config/app.yml` get loaded directly into `Rails.config`.

### 3. Loads and combines encrypted credentials

Ravioli will then check for [encrypted credentials](https://guides.rubyonrails.org/security.html#custom-credentials). It loads credentials in the following order:

1. First, it loads `config/credentials.yml.enc`
2. Then, it loads and applies `config/credentials/RAILS_ENV.yml.enc` over top of what it has already loaded
3. Finally, IF `Rails.config.staging?` IS TRUE, it loads and applies `config/credentials/staging.yml.enc`

This allows you to use your secure credentials stores without duplicating information; you can simply layer environment-specific values over top of

### All put together, it does this:

```ruby
def Rails.config
  @config ||= Ravioli.build(strict: Rails.env.production?) do |config|
    config.add_staging_flag!
    config.auto_load_files!
    config.auto_load_credentials!
  end
end
```

I documented that because, you know, you can do parts of that yourself when we get into the weeds with.........

## Manual configuration

If any of the above doesn't suit you, by all means, Ravioli is flexible enough for you to build your own instance. There are a number of things you can change, so read through to see what you can do by going your own way.

### Using `Ravioli.build`

The best way to build your own configuration is by calling `Ravioli.build`. It will yield an instance of a `Ravioli::Builder`, which has lots of convenient methods for loading configuration files, credentials, and the like. It works like so:

```ruby
configuration = Ravioli.build do |config|
  config.load_file("things.yml")
  config.whatever = {things: true}
end
```

This will return a configured instance of `Ravioli::Configuration` with structure

```yaml
things:
  # ...the contents of things.yml
whatever:
  things: true
```

`Ravioli.build` also does a few handy things:

- It freezes the configuration object so it is immutable,
- It caches the final configuration in `Ravioli.configurations`, and
- It sets `Ravioli.default` to the most-recently built configuration

### Direct construction with `Ravioli::Configuration.new`

You can also directly construct a configuration object by passing a hash to `Ravioli::Configuration.new`. This is basically the same thing as an `OpenStruct` with the added [helper methods of a Ravioli object](#usage):

```ruby
config = Ravioli::Configuration.new(whatever: true, test: {things: "stuff"})
config.dig(:test, :things) #=> "stuff
```

### Alternatives to using `Rails.config`

By default, Ravioli loads a default configuration in `Rails.config`. If you are already using `Rails.config` for something else, or you just hate the idea of all those letters, you can do it however else makes sense to you: in a constant (e.g. `Config` or `App`), or somewhere else entirely (you could, for example, define a `Config` module, mix it in to your classes where it's needed, and access it via a `config` instance method).

Here's an example using an `App` constant:

```ruby
# config/initializers/_config.rb
App = Raviloli.build { |config| ... }
```

You can also point it to `Rails.config` if you'd like to access configuration somewhere other than `Rails.config`, but you want to enjoy the benefits of [automatic configuration](#automatic-configuration):

```ruby
# config/initializers/_config.rb
App = Rails.config
```

You could also opt-in to configuration access with a module:

```ruby
module Config
  def config
    Ravioli.default || Ravioli.build {|config| ... }
  end
end
```

### `add_staging_flag!`


### `load_file`

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


```ruby
# config/initializers/_ravioli.rb`
Config = Ravioli.build do
  load_file(:mailjet) # given a symbol, it automatically assumes you meant `config/mailjet.yml`
  load_file("config/mailjet") # same as above
  load_file("lib/mailjet/config") # looks for `Rails.root.join("lib", "mailjet", "config.yml")
end
```

`config/initializers/_ravioli.rb`

```ruby
Config = Ravioli.build do |config|
  %i[new_relic sentry google].each do |service|
    config.load_file(service)
  end

  config.load_credentials # just load the base credentials file
  config.load_credentials("credentials/production") if Rails.env.production? # add production overrides when appropriate

  config.staging = File.exists?("./staging.txt") # technically you could do this ... I don't know why you would, but technically you could
end
```

Configuration values take precedence in the order they are applied. For example, if you load two config files defining `host`, the latest one will overwrite the earlier one's value.


### `load_credentials`

Imagine the following encrypted YAML files:

#### `config/credentials.yml.enc`

Accessing the credentials with `rails credentials:edit`, let's say you have the following encrypted file:

```yaml
mailet:
  api_key: "12345"
```

#### `config/credentials/production.yml.enc`

Edit with `rails credentials:edit --environment production`

```yaml
mailet:
  api_key: "67891"
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



You can manually define your configuration in an initializer if you don't want the automatic configuration assumptions to step on any toes.

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

## Deploying

### Encryption keys in ENV

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

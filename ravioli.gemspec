# frozen_string_literal: true

require_relative "lib/ravioli/version"

Gem::Specification.new do |spec|
  spec.name = "ravioli"
  spec.version = Ravioli::VERSION
  spec.authors = ["Flip Sasser"]
  spec.email = ["hello@flipsasser.com"]

  spec.summary = "Grab a fork and twist all your configuration spaghetti into a single, delicious bundle"
  spec.description = "Ravioli combines all of your app's runtime configuration into a unified, simple interface. It automatically loads and combines YAML config files, encrypted Rails credentials, and ENV vars so you can focus on writing code and not on where configuration comes from"
  spec.homepage = "https://github.com/flipsasser/ravioli"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  # spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] =

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0", "< 7.2"

  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "guard-rubocop"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rails", ">= 7.0", "< 7.2"
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "rubocop", ">= 1.0"
  spec.add_development_dependency "rubocop-ordered_methods", "~> 0.6"
  spec.add_development_dependency "rubocop-performance", ">= 1.5"
  spec.add_development_dependency "rubocop-rails", ">= 2.5.0"
  spec.add_development_dependency "rubocop-rspec", ">= 2.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "standard", "~> 0.13.0"
  spec.add_development_dependency "yard", "~> 0.9"
end

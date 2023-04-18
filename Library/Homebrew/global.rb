# typed: true
# frozen_string_literal: true

require_relative "startup"

require "English"
require "fileutils"
require "json"
require "json/add/exception"
require "ostruct"
require "forwardable"

# Only require "core_ext" here to ensure we're only requiring the minimum of
# what we need.
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/filters"
require "active_support/core_ext/object/try"
require "active_support/core_ext/array/access"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/array/conversions"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/file/atomic"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/exclude"
require "active_support/core_ext/string/indent"

I18n.backend.available_locales # Initialize locales so they can be overwritten.
I18n.backend.store_translations :en, support: { array: { last_word_connector: " and " } }

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "formula", "formulae"
  inflect.irregular "is", "are"
  inflect.irregular "it", "they"
end

HOMEBREW_API_DEFAULT_DOMAIN = ENV.fetch("HOMEBREW_API_DEFAULT_DOMAIN").freeze
HOMEBREW_BOTTLE_DEFAULT_DOMAIN = ENV.fetch("HOMEBREW_BOTTLE_DEFAULT_DOMAIN").freeze
HOMEBREW_BREW_DEFAULT_GIT_REMOTE = ENV.fetch("HOMEBREW_BREW_DEFAULT_GIT_REMOTE").freeze
HOMEBREW_CORE_DEFAULT_GIT_REMOTE = ENV.fetch("HOMEBREW_CORE_DEFAULT_GIT_REMOTE").freeze
HOMEBREW_DEFAULT_CACHE = ENV.fetch("HOMEBREW_DEFAULT_CACHE").freeze
HOMEBREW_DEFAULT_LOGS = ENV.fetch("HOMEBREW_DEFAULT_LOGS").freeze
HOMEBREW_DEFAULT_TEMP = ENV.fetch("HOMEBREW_DEFAULT_TEMP").freeze
HOMEBREW_REQUIRED_RUBY_VERSION = ENV.fetch("HOMEBREW_REQUIRED_RUBY_VERSION").freeze

HOMEBREW_PRODUCT = ENV.fetch("HOMEBREW_PRODUCT").freeze
HOMEBREW_VERSION = ENV.fetch("HOMEBREW_VERSION").freeze
HOMEBREW_WWW = "https://brew.sh"
HOMEBREW_DOCS_WWW = "https://docs.brew.sh"
HOMEBREW_SYSTEM = ENV.fetch("HOMEBREW_SYSTEM").freeze
HOMEBREW_PROCESSOR = ENV.fetch("HOMEBREW_PROCESSOR").freeze
HOMEBREW_PHYSICAL_PROCESSOR = ENV.fetch("HOMEBREW_PHYSICAL_PROCESSOR").freeze

HOMEBREW_BREWED_CURL_PATH = Pathname(ENV.fetch("HOMEBREW_BREWED_CURL_PATH")).freeze
HOMEBREW_USER_AGENT_CURL = ENV.fetch("HOMEBREW_USER_AGENT_CURL").freeze
HOMEBREW_USER_AGENT_RUBY =
  "#{ENV.fetch("HOMEBREW_USER_AGENT")} ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
HOMEBREW_USER_AGENT_FAKE_SAFARI =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/602.4.8 " \
  "(KHTML, like Gecko) Version/10.0.3 Safari/602.4.8"
HOMEBREW_GITHUB_PACKAGES_AUTH = ENV.fetch("HOMEBREW_GITHUB_PACKAGES_AUTH").freeze

HOMEBREW_DEFAULT_PREFIX = "/usr/local"
HOMEBREW_DEFAULT_REPOSITORY = "#{HOMEBREW_DEFAULT_PREFIX}/Homebrew"
HOMEBREW_MACOS_ARM_DEFAULT_PREFIX = "/opt/homebrew"
HOMEBREW_MACOS_ARM_DEFAULT_REPOSITORY = HOMEBREW_MACOS_ARM_DEFAULT_PREFIX
HOMEBREW_LINUX_DEFAULT_PREFIX = "/home/linuxbrew/.linuxbrew"
HOMEBREW_LINUX_DEFAULT_REPOSITORY = "#{HOMEBREW_LINUX_DEFAULT_PREFIX}/Homebrew"
HOMEBREW_PREFIX_PLACEHOLDER = "$HOMEBREW_PREFIX"

HOMEBREW_PULL_API_REGEX =
  %r{https://api\.github\.com/repos/([\w-]+)/([\w-]+)?/pulls/(\d+)}.freeze
HOMEBREW_PULL_OR_COMMIT_URL_REGEX =
  %r[https://github\.com/([\w-]+)/([\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})].freeze
HOMEBREW_BOTTLES_EXTNAME_REGEX = /\.([a-z0-9_]+)\.bottle\.(?:(\d+)\.)?tar\.gz$/.freeze

require "env_config"
require "compat/early" unless Homebrew::EnvConfig.no_compat?
require "macos_versions"
require "os"
require "messages"
require "default_prefix"

module Homebrew
  extend FileUtils

  DEFAULT_CELLAR = "#{DEFAULT_PREFIX}/Cellar"
  DEFAULT_MACOS_CELLAR = "#{HOMEBREW_DEFAULT_PREFIX}/Cellar"
  DEFAULT_MACOS_ARM_CELLAR = "#{HOMEBREW_MACOS_ARM_DEFAULT_PREFIX}/Cellar"
  DEFAULT_LINUX_CELLAR = "#{HOMEBREW_LINUX_DEFAULT_PREFIX}/Cellar"

  class << self
    attr_writer :failed, :raise_deprecation_exceptions, :auditing

    def default_prefix?(prefix = HOMEBREW_PREFIX)
      prefix.to_s == DEFAULT_PREFIX
    end

    def failed?
      @failed ||= false
      @failed == true
    end

    def messages
      @messages ||= Messages.new
    end

    def raise_deprecation_exceptions?
      @raise_deprecation_exceptions == true
    end

    def auditing?
      @auditing == true
    end
  end
end

require "context"
require "extend/git_repository"
require "extend/pathname"
require "extend/predicable"
require "extend/module"
require "cli/args"

require "PATH"

ENV["HOMEBREW_PATH"] ||= ENV.fetch("PATH")
ORIGINAL_PATHS = PATH.new(ENV.fetch("HOMEBREW_PATH")).map do |p|
  Pathname.new(p).expand_path
rescue
  nil
end.compact.freeze

require "set"

require "system_command"
require "exceptions"
require "utils"

require "official_taps"
require "tap"
require "tap_constants"

require "compat/late" unless Homebrew::EnvConfig.no_compat?

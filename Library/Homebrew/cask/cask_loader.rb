# typed: false
# frozen_string_literal: true

require "cask/cache"
require "cask/cask"
require "uri"

module Cask
  # Loads a cask from various sources.
  #
  # @api private
  module CaskLoader
    extend Context

    # Loads a cask from a string.
    class FromContentLoader
      attr_reader :content

      def self.can_load?(ref)
        return false unless ref.respond_to?(:to_str)

        content = ref.to_str

        # Cache compiled regex
        @regex ||= begin
          token  = /(?:"[^"]*"|'[^']*')/
          curly  = /\(\s*#{token.source}\s*\)\s*\{.*\}/
          do_end = /\s+#{token.source}\s+do(?:\s*;\s*|\s+).*end/
          /\A\s*cask(?:#{curly.source}|#{do_end.source})\s*\Z/m
        end

        content.match?(@regex)
      end

      def initialize(content)
        @content = content.force_encoding("UTF-8")
      end

      def load(config:)
        @config = config

        instance_eval(content, __FILE__, __LINE__)
      end

      private

      def cask(header_token, **options, &block)
        Cask.new(header_token, source: content, **options, config: @config, &block)
      end
    end

    # Loads a cask from a path.
    class FromPathLoader < FromContentLoader
      def self.can_load?(ref)
        path = Pathname(ref)
        %w[.rb .json].include?(path.extname) && path.expand_path.exist?
      end

      attr_reader :token, :path

      def initialize(path) # rubocop:disable Lint/MissingSuper
        path = Pathname(path).expand_path

        @token = path.basename(path.extname).to_s
        @path = path
      end

      def load(config:)
        raise CaskUnavailableError.new(token, "'#{path}' does not exist.")  unless path.exist?
        raise CaskUnavailableError.new(token, "'#{path}' is not readable.") unless path.readable?
        raise CaskUnavailableError.new(token, "'#{path}' is not a file.")   unless path.file?

        @content = path.read(encoding: "UTF-8")
        @config = config

        if path.extname == ".json"
          return FromAPILoader.new(token, from_json: JSON.parse(@content)).load(config: config)
        end

        begin
          instance_eval(content, path).tap do |cask|
            raise CaskUnreadableError.new(token, "'#{path}' does not contain a cask.") unless cask.is_a?(Cask)
          end
        rescue NameError, ArgumentError, ScriptError => e
          error = CaskUnreadableError.new(token, e.message)
          error.set_backtrace e.backtrace
          raise error
        end
      end

      private

      def cask(header_token, **options, &block)
        raise CaskTokenMismatchError.new(token, header_token) if token != header_token

        super(header_token, **options, sourcefile_path: path, &block)
      end
    end

    # Loads a cask from a URI.
    class FromURILoader < FromPathLoader
      extend T::Sig

      def self.can_load?(ref)
        # Cache compiled regex
        @uri_regex ||= begin
          uri_regex = ::URI::DEFAULT_PARSER.make_regexp
          Regexp.new("\\A#{uri_regex.source}\\Z", uri_regex.options)
        end

        return false unless ref.to_s.match?(@uri_regex)

        uri = URI(ref)
        return false unless uri
        return false unless uri.path

        true
      end

      attr_reader :url

      sig { params(url: T.any(URI::Generic, String)).void }
      def initialize(url)
        @url = URI(url)
        super Cache.path/File.basename(@url.path)
      end

      def load(config:)
        path.dirname.mkpath

        begin
          ohai "Downloading #{url}"
          curl_download url, to: path
        rescue ErrorDuringExecution
          raise CaskUnavailableError.new(token, "Failed to download #{Formatter.url(url)}.")
        end

        super
      end
    end

    # Loads a cask from a tap path.
    class FromTapPathLoader < FromPathLoader
      def self.can_load?(ref)
        super && !Tap.from_path(ref).nil?
      end

      attr_reader :tap

      def initialize(path)
        @tap = Tap.from_path(path)
        super(path)
      end

      private

      def cask(*args, &block)
        super(*args, tap: tap, &block)
      end
    end

    # Loads a cask from a specific tap.
    class FromTapLoader < FromTapPathLoader
      def self.can_load?(ref)
        ref.to_s.match?(HOMEBREW_TAP_CASK_REGEX)
      end

      def initialize(tapped_name)
        user, repo, token = tapped_name.split("/", 3)
        super Tap.fetch(user, repo).cask_dir/"#{token}.rb"
      end

      def load(config:)
        raise TapCaskUnavailableError.new(tap, token) unless tap.installed?

        super
      end
    end

    # Loads a cask from the default tap path.
    class FromDefaultTapPathLoader < FromTapPathLoader
      def self.can_load?(ref)
        super CaskLoader.default_path(ref)
      end

      def initialize(ref)
        super CaskLoader.default_path(ref)
      end
    end

    # Loads a cask from an existing {Cask} instance.
    class FromInstanceLoader
      def self.can_load?(ref)
        ref.is_a?(Cask)
      end

      def initialize(cask)
        @cask = cask
      end

      def load(config:)
        @cask
      end
    end

    # Loads a cask from the JSON API.
    class FromAPILoader
      attr_reader :token, :path

      FLIGHT_STANZAS = [:preflight, :postflight, :uninstall_preflight, :uninstall_postflight].freeze

      def self.can_load?(ref)
        return false unless Homebrew::EnvConfig.install_from_api?
        return false unless ref.is_a?(String)
        return false unless ref.match?(HOMEBREW_MAIN_TAP_CASK_REGEX)

        token = ref.delete_prefix("homebrew/cask/")
        Homebrew::API::Cask.all_casks.key?(token)
      end

      def initialize(token, from_json: nil)
        @token = token.delete_prefix("homebrew/cask/")
        @path = CaskLoader.default_path(token)
        @from_json = from_json
      end

      def load(config:)
        json_cask = @from_json || Homebrew::API::Cask.all_casks[token]
        cask_source = JSON.pretty_generate(json_cask)

        json_cask = Homebrew::API.merge_variations(json_cask).deep_symbolize_keys

        # Use the cask-source API if there are any `*flight` blocks or the cask has multiple languages
        if json_cask[:artifacts].any? { |artifact| FLIGHT_STANZAS.include?(artifact.keys.first) } ||
           json_cask[:languages].any?
          cask_source = Homebrew::API::Cask.fetch_source(token, git_head: json_cask[:tap_git_head])
          return FromContentLoader.new(cask_source).load(config: config)
        end

        tap = Tap.fetch(json_cask[:tap]) if json_cask[:tap].to_s.include?("/")

        Cask.new(token, tap: tap, source: cask_source, config: config, loaded_from_api: true, loader: self) do
          version json_cask[:version]

          if json_cask[:sha256] == "no_check"
            sha256 :no_check
          else
            sha256 json_cask[:sha256]
          end

          url json_cask[:url]
          appcast json_cask[:appcast] if json_cask[:appcast].present?
          json_cask[:name].each do |cask_name|
            name cask_name
          end
          desc json_cask[:desc]
          homepage json_cask[:homepage]

          auto_updates json_cask[:auto_updates] if json_cask[:auto_updates].present?
          conflicts_with(**json_cask[:conflicts_with]) if json_cask[:conflicts_with].present?

          if json_cask[:depends_on].present?
            dep_hash = json_cask[:depends_on].to_h do |dep_key, dep_value|
              # Arch dependencies are encoded like `{ type: :intel, bits: 64 }`
              # but `depends_on arch:` only accepts `:intel` or `:arm64`
              if dep_key == :arch
                next [:arch, :intel] if dep_value.first[:type] == "intel"

                next [:arch, :arm64]
              end

              next [dep_key, dep_value] unless dep_key == :macos

              dep_type = dep_value.keys.first
              if dep_type == :==
                version_symbols = dep_value[dep_type].map do |version|
                  MacOSVersions::SYMBOLS.key(version) || version
                end
                next [dep_key, version_symbols]
              end

              version_symbol = dep_value[dep_type].first
              version_symbol = MacOSVersions::SYMBOLS.key(version_symbol) || version_symbol
              [dep_key, "#{dep_type} :#{version_symbol}"]
            end.compact
            depends_on(**dep_hash)
          end

          if json_cask[:container].present?
            container_hash = json_cask[:container].to_h do |container_key, container_value|
              next [container_key, container_value] unless container_key == :type

              [container_key, container_value.to_sym]
            end
            container(**container_hash)
          end

          json_cask[:artifacts].each do |artifact|
            # convert generic string replacements into actual ones
            artifact = cask.loader.from_h_hash_gsubs(artifact, appdir)
            key = artifact.keys.first
            send(key, *artifact[key])
          end

          if json_cask[:caveats].present?
            # convert generic string replacements into actual ones
            json_cask[:caveats] = cask.loader.from_h_string_gsubs(json_cask[:caveats], appdir)
            caveats json_cask[:caveats]
          end
        end
      end

      def from_h_string_gsubs(string, appdir)
        # TODO: HOMEBREW_OLD_PREFIX_PLACEHOLDER can be removed when API JSON is
        #       regenerated with HOMEBREW_PREFIX_PLACEHOLDER.
        string.to_s
              .gsub(Cask::HOME_PLACEHOLDER, Dir.home)
              .gsub(Cask::HOMEBREW_PREFIX_PLACEHOLDER, HOMEBREW_PREFIX)
              .gsub(Cask::APPDIR_PLACEHOLDER, appdir)
              .gsub(Cask::HOMEBREW_OLD_PREFIX_PLACEHOLDER, HOMEBREW_PREFIX)
      end

      def from_h_array_gsubs(array, appdir)
        array.to_a.map do |value|
          from_h_gsubs(value, appdir)
        end
      end

      def from_h_hash_gsubs(hash, appdir)
        hash.to_h.transform_values do |value|
          from_h_gsubs(value, appdir)
        end
      rescue TypeError
        from_h_array_gsubs(hash, appdir)
      end

      def from_h_gsubs(value, appdir)
        return value if value.blank?

        if value.respond_to? :to_h
          from_h_hash_gsubs(value, appdir)
        elsif value.respond_to? :to_a
          from_h_array_gsubs(value, appdir)
        elsif value.is_a? String
          from_h_string_gsubs(value, appdir)
        else
          value
        end
      end
    end

    # Pseudo-loader which raises an error when trying to load the corresponding cask.
    class NullLoader < FromPathLoader
      extend T::Sig

      def self.can_load?(*)
        true
      end

      sig { params(ref: T.any(String, Pathname)).void }
      def initialize(ref)
        token = File.basename(ref, ".rb")
        super CaskLoader.default_path(token)
      end

      def load(config:)
        raise CaskUnavailableError.new(token, "No Cask with this name exists.")
      end
    end

    def self.path(ref)
      self.for(ref, need_path: true).path
    end

    def self.load(ref, config: nil)
      self.for(ref).load(config: config)
    end

    def self.for(ref, need_path: false)
      [
        FromInstanceLoader,
        FromContentLoader,
        FromURILoader,
        FromAPILoader,
        FromTapLoader,
        FromTapPathLoader,
        FromPathLoader,
        FromDefaultTapPathLoader,
      ].each do |loader_class|
        if loader_class.can_load?(ref)
          $stderr.puts "#{$PROGRAM_NAME} (#{loader_class}): loading #{ref}" if debug?
          return loader_class.new(ref)
        end
      end

      case (possible_tap_casks = tap_paths(ref)).count
      when 1
        return FromTapPathLoader.new(possible_tap_casks.first)
      when 2..Float::INFINITY
        loaders = possible_tap_casks.map(&FromTapPathLoader.method(:new))

        raise TapCaskAmbiguityError.new(ref, loaders)
      end

      possible_installed_cask = Cask.new(ref)
      return FromPathLoader.new(possible_installed_cask.installed_caskfile) if possible_installed_cask.installed?

      NullLoader.new(ref)
    end

    def self.default_path(token)
      Tap.default_cask_tap.cask_dir/"#{token.to_s.downcase}.rb"
    end

    def self.tap_paths(token)
      Tap.map { |t| t.cask_dir/"#{token.to_s.downcase}.rb" }
         .select(&:exist?)
    end
  end
end

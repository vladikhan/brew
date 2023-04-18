# typed: false
# frozen_string_literal: true

require "cli/parser"

module Homebrew
  extend T::Sig

  module_function

  sig { returns(CLI::Parser) }
  def typecheck_args
    Homebrew::CLI::Parser.new do
      description <<~EOS
        Check for typechecking errors using Sorbet.
      EOS
      switch "--fix",
             description: "Automatically fix type errors."
      switch "-q", "--quiet",
             description: "Silence all non-critical errors."
      switch "--update",
             description: "Update RBI files."
      switch "--update-all",
             description: "Update all RBI files rather than just updated gems."
      switch "--suggest-typed",
             depends_on:  "--update",
             description: "Try upgrading `typed` sigils."
      switch "--fail-if-not-changed",
             hidden:      true,
             description: "Return a failing status code if all gems are up to date " \
                          "and gem definitions do not need a tapioca update."
      flag   "--dir=",
             description: "Typecheck all files in a specific directory."
      flag   "--file=",
             description: "Typecheck a single file."
      flag   "--ignore=",
             description: "Ignores input files that contain the given string " \
                          "in their paths (relative to the input path passed to Sorbet)."

      conflicts "--dir", "--file"

      named_args :none
    end
  end

  sig { void }
  def typecheck
    args = typecheck_args.parse

    Homebrew.install_bundler_gems!(groups: ["sorbet"])

    HOMEBREW_LIBRARY_PATH.cd do
      if args.update? || args.update_all?
        odisabled "brew typecheck --update --fail-if-not-changed" if args.fail_if_not_changed?

        excluded_gems = [
          "did_you_mean", # RBI file is already provided by Sorbet
          "webrobots", # RBI file is bugged
          "sorbet-static-and-runtime", # Unnecessary RBI - remove this entry with Tapioca 0.8
        ]
        typed_overrides = [
          "msgpack:false", # Investigate removing this with Tapioca 0.8
        ]
        tapioca_args = ["--exclude", *excluded_gems, "--typed-overrides", *typed_overrides]
        tapioca_args << "--all" if args.update_all?

        ohai "Updating Tapioca RBI files..."
        safe_system "bundle", "exec", "tapioca", "gem", *tapioca_args
        safe_system "bundle", "exec", "parlour"
        safe_system "bundle", "exec", "srb", "rbi", "hidden-definitions"
        safe_system "bundle", "exec", "tapioca", "todo"

        if args.suggest_typed?
          ohai "Bumping Sorbet `typed` sigils..."
          safe_system "bundle", "exec", "spoom", "bump"
        end

        return
      end

      srb_exec = %w[bundle exec srb tc]

      srb_exec << "--quiet" if args.quiet?

      if args.fix?
        # Auto-correcting method names is almost always wrong.
        srb_exec << "--suppress-error-code" << "7003"

        srb_exec << "--autocorrect"
      end

      srb_exec += ["--ignore", args.ignore] if args.ignore.present?
      if args.file.present? || args.dir.present?
        cd("sorbet")
        srb_exec += ["--file", "../#{args.file}"] if args.file
        srb_exec += ["--dir", "../#{args.dir}"] if args.dir
      end
      success = system(*srb_exec)
      return if success

      $stderr.puts "Check #{Formatter.url("https://docs.brew.sh/Typechecking")} for " \
                   "more information on how to resolve these errors."
      Homebrew.failed = true
    end
  end
end

# typed: false
# frozen_string_literal: true

require "cli/parser"

module Homebrew
  extend T::Sig

  module_function

  sig { returns(CLI::Parser) }
  def cat_args
    Homebrew::CLI::Parser.new do
      description <<~EOS
        Display the source of a <formula> or <cask>.
      EOS

      switch "--formula", "--formulae",
             description: "Treat all named arguments as formulae."
      switch "--cask", "--casks",
             description: "Treat all named arguments as casks."

      conflicts "--formula", "--cask"

      named_args [:formula, :cask], min: 1
    end
  end

  def cat
    args = cat_args.parse

    cd HOMEBREW_REPOSITORY
    pager = if Homebrew::EnvConfig.bat?
      ENV["BAT_CONFIG_PATH"] = Homebrew::EnvConfig.bat_config_path
      ENV["BAT_THEME"] = Homebrew::EnvConfig.bat_theme
      ensure_formula_installed!(
        "bat",
        reason:           "displaying <formula>/<cask> source",
        # The user might want to capture the output of `brew cat ...`
        # Redirect stdout to stderr
        output_to_stderr: true,
      ).opt_bin/"bat"
    else
      "cat"
    end

    safe_system pager, *args.named.to_paths
  end
end

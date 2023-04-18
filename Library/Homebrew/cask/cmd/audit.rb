# typed: false
# frozen_string_literal: true

require "utils/github/actions"

module Cask
  class Cmd
    # Cask implementation of the `brew audit` command.
    #
    # @api private
    class Audit < AbstractCommand
      extend T::Sig

      def self.parser
        super do
          switch "--[no-]download",
                 description: "Audit the downloaded file"
          switch "--[no-]appcast",
                 description: "Audit the appcast"
          switch "--[no-]token-conflicts",
                 description: "Audit for token conflicts"
          switch "--[no-]signing",
                 description: "Audit for signed apps, which is required on ARM"
          switch "--[no-]strict",
                 description: "Run additional, stricter style checks"
          switch "--[no-]online",
                 description: "Run additional, slower style checks that require a network connection"
          switch "--new-cask",
                 description: "Run various additional style checks to determine if a new cask is eligible " \
                              "for Homebrew. This should be used when creating new casks and implies " \
                              "`--strict` and `--online`"
          switch "--display-failures-only",
                 description: "Only display casks that fail the audit. This is the default for formulae."
        end
      end

      sig { void }
      def run
        casks = args.named.flat_map do |name|
          next name if File.exist?(name)
          next Tap.fetch(name).cask_files if name.count("/") == 1

          name
        end
        casks = casks.map { |c| CaskLoader.load(c, config: Config.from_args(args)) }
        any_named_args = casks.any?
        casks = Cask.to_a if casks.empty?

        results = self.class.audit_casks(
          *casks,
          download:              args.download?,
          appcast:               args.appcast?,
          online:                args.online?,
          strict:                args.strict?,
          signing:               args.signing?,
          new_cask:              args.new_cask?,
          token_conflicts:       args.token_conflicts?,
          quarantine:            args.quarantine?,
          any_named_args:        any_named_args,
          language:              args.language,
          display_passes:        args.verbose? || args.named.count == 1,
          display_failures_only: args.display_failures_only?,
          only:                  [],
          except:                [],
        )

        failed_casks = results.reject { |_, result| result[:errors].empty? }.map(&:first)
        return if failed_casks.empty?

        raise CaskError, "audit failed for casks: #{failed_casks.join(" ")}"
      end

      def self.audit_casks(
        *casks,
        download:,
        appcast:,
        online:,
        strict:,
        signing:,
        new_cask:,
        token_conflicts:,
        quarantine:,
        any_named_args:,
        language:,
        display_passes:,
        display_failures_only:,
        only:,
        except:
      )
        options = {
          audit_download:        download,
          audit_appcast:         appcast,
          audit_online:          online,
          audit_strict:          strict,
          audit_signing:         signing,
          audit_new_cask:        new_cask,
          audit_token_conflicts: token_conflicts,
          quarantine:            quarantine,
          language:              language,
          any_named_args:        any_named_args,
          display_passes:        display_passes,
          display_failures_only: display_failures_only,
          only:                  only,
          except:                except,
        }.compact

        options[:quarantine] = true if options[:quarantine].nil?

        Homebrew.auditing = true

        require "cask/auditor"

        casks.to_h do |cask|
          odebug "Auditing Cask #{cask}"
          [cask.sourcefile_path, Auditor.audit(cask, **options)]
        end
      end
    end
  end
end

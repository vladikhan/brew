# typed: false
# frozen_string_literal: true

require "rubocops/rubocop-cask"
require "test/rubocops/cask/shared_examples/cask_cop"

describe RuboCop::Cop::Cask::StanzaOrder do
  include CaskCop

  subject(:cop) { described_class.new }

  context "when there is only one stanza" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          version :latest
        end
      CASK
    end

    include_examples "does not report any offenses"
  end

  context "when no stanzas are out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          arch arm: "arm", intel: "x86_64"
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"
          version :latest
          sha256 :no_check
          foo = "bar"
        end
      CASK
    end

    include_examples "does not report any offenses"
  end

  context "when one pair of stanzas is out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          sha256 :no_check
          version :latest
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
        end
      CASK
    end
    let(:expected_offenses) do
      [{
        message:  "`sha256` stanza out of order",
        severity: :convention,
        line:     2,
        column:   2,
        source:   "sha256 :no_check",
      }, {
        message:  "`version` stanza out of order",
        severity: :convention,
        line:     3,
        column:   2,
        source:   "version :latest",
      }]
    end

    include_examples "reports offenses"

    include_examples "autocorrects source"
  end

  context "when the arch stanza is out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
          arch arm: "arm", intel: "x86_64"
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          arch arm: "arm", intel: "x86_64"
          version :latest
          sha256 :no_check
        end
      CASK
    end
    let(:expected_offenses) do
      [{
        message:  "`version` stanza out of order",
        severity: :convention,
        line:     2,
        column:   2,
        source:   "version :latest",
      }, {
        message:  "`sha256` stanza out of order",
        severity: :convention,
        line:     3,
        column:   2,
        source:   "sha256 :no_check",
      }, {
        message:  "`arch` stanza out of order",
        severity: :convention,
        line:     4,
        column:   2,
        source:   'arch arm: "arm", intel: "x86_64"',
      }]
    end

    include_examples "reports offenses"

    include_examples "autocorrects source"
  end

  context "when an arch variable assignment is out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          arch arm: "arm", intel: "x86_64"
          sha256 :no_check
          version :latest
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          arch arm: "arm", intel: "x86_64"
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"
          version :latest
          sha256 :no_check
        end
      CASK
    end
    let(:expected_offenses) do
      [{
        message:  "`sha256` stanza out of order",
        severity: :convention,
        line:     3,
        column:   2,
        source:   "sha256 :no_check",
      }, {
        message:  "`on_arch_conditional` stanza out of order",
        severity: :convention,
        line:     5,
        column:   2,
        source:   'folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"',
      }]
    end

    include_examples "reports offenses"

    include_examples "autocorrects source"
  end

  context "when an arch variable assignment is above the arch stanza" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"
          arch arm: "arm", intel: "x86_64"
          version :latest
          sha256 :no_check
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          arch arm: "arm", intel: "x86_64"
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"
          version :latest
          sha256 :no_check
        end
      CASK
    end
    let(:expected_offenses) do
      [{
        message:  "`on_arch_conditional` stanza out of order",
        severity: :convention,
        line:     2,
        column:   2,
        source:   'folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin"',
      }, {
        message:  "`arch` stanza out of order",
        severity: :convention,
        line:     3,
        column:   2,
        source:   'arch arm: "arm", intel: "x86_64"',
      }]
    end

    include_examples "reports offenses"

    include_examples "autocorrects source"
  end

  context "when many stanzas are out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          url 'https://foo.brew.sh/foo.zip'
          uninstall :quit => 'com.example.foo',
                    :kext => 'com.example.foo.kext'
          version :latest
          app 'Foo.app'
          sha256 :no_check
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
          url 'https://foo.brew.sh/foo.zip'
          app 'Foo.app'
          uninstall :quit => 'com.example.foo',
                    :kext => 'com.example.foo.kext'
        end
      CASK
    end
    let(:expected_offenses) do
      [{
        message:  "`url` stanza out of order",
        severity: :convention,
        line:     2,
        column:   2,
        source:   "url 'https://foo.brew.sh/foo.zip'",
      }, {
        message:  "`uninstall` stanza out of order",
        severity: :convention,
        line:     3,
        column:   2,
        source:   "uninstall :quit => 'com.example.foo'," \
                  "\n            :kext => 'com.example.foo.kext'",
      }, {
        message:  "`version` stanza out of order",
        severity: :convention,
        line:     5,
        column:   2,
        source:   "version :latest",
      }, {
        message:  "`sha256` stanza out of order",
        severity: :convention,
        line:     7,
        column:   2,
        source:   "sha256 :no_check",
      }]
    end

    include_examples "reports offenses"

    include_examples "autocorrects source"
  end

  context "when a stanza appears multiple times" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          name 'Foo'
          url 'https://foo.brew.sh/foo.zip'
          name 'FancyFoo'
          version :latest
          app 'Foo.app'
          sha256 :no_check
          name 'FunkyFoo'
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
          url 'https://foo.brew.sh/foo.zip'
          name 'Foo'
          name 'FancyFoo'
          name 'FunkyFoo'
          app 'Foo.app'
        end
      CASK
    end

    it "preserves the original order" do
      expect_autocorrected_source(source, correct_source)
    end
  end

  context "when a stanza has a comment" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          version :latest
          # comment with an empty line between

          # comment directly above
          postflight do
            puts 'We have liftoff!'
          end
          sha256 :no_check # comment on same line
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check # comment on same line
          # comment with an empty line between

          # comment directly above
          postflight do
            puts 'We have liftoff!'
          end
        end
      CASK
    end

    include_examples "autocorrects source"
  end

  context "when a variable assignment is out of order with a comment" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
          # comment with an empty line between

          # comment directly above
          postflight do
            puts 'We have liftoff!'
          end
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin" # comment on same line
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          folder = on_arch_conditional arm: "darwin-arm64", intel: "darwin" # comment on same line
          version :latest
          sha256 :no_check
          # comment with an empty line between

          # comment directly above
          postflight do
            puts 'We have liftoff!'
          end
        end
      CASK
    end

    include_examples "autocorrects source"
  end

  context "when the caveats stanza is out of order" do
    let(:source) do
      format(<<~CASK, caveats: caveats.strip)
        cask 'foo' do
          name 'Foo'
          url 'https://foo.brew.sh/foo.zip'
          %<caveats>s
          version :latest
          app 'Foo.app'
          sha256 :no_check
        end
      CASK
    end
    let(:correct_source) do
      format(<<~CASK, caveats: caveats.strip)
        cask 'foo' do
          version :latest
          sha256 :no_check
          url 'https://foo.brew.sh/foo.zip'
          name 'Foo'
          app 'Foo.app'
          %<caveats>s
        end
      CASK
    end

    context "when caveats is a one-line string" do
      let(:caveats) { "caveats 'This is a one-line caveat.'" }

      include_examples "autocorrects source"
    end

    context "when caveats is a heredoc" do
      let(:caveats) do
        <<~CAVEATS
          caveats <<~EOS
              This is a multiline caveat.

              Let's hope it doesn't cause any problems!
            EOS
        CAVEATS
      end

      include_examples "autocorrects source"
    end

    context "when caveats is a block" do
      let(:caveats) do
        <<~CAVEATS
          caveats do
              puts 'This is a multiline caveat.'

              puts "Let's hope it doesn't cause any problems!"
            end
        CAVEATS
      end

      include_examples "autocorrects source"
    end
  end

  context "when the postflight stanza is out of order" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          name 'Foo'
          url 'https://foo.brew.sh/foo.zip'
          postflight do
            puts 'We have liftoff!'
          end
          version :latest
          app 'Foo.app'
          sha256 :no_check
        end
      CASK
    end
    let(:correct_source) do
      <<~CASK
        cask 'foo' do
          version :latest
          sha256 :no_check
          url 'https://foo.brew.sh/foo.zip'
          name 'Foo'
          app 'Foo.app'
          postflight do
            puts 'We have liftoff!'
          end
        end
      CASK
    end

    include_examples "autocorrects source"
  end

  # TODO: detect out-of-order stanzas in nested expressions
  context "when stanzas are nested in a conditional expression" do
    let(:source) do
      <<~CASK
        cask 'foo' do
          if true
            sha256 :no_check
            version :latest
          end
        end
      CASK
    end

    include_examples "does not report any offenses"
  end
end

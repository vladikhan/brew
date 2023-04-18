# typed: false
# frozen_string_literal: true

describe Cask::Cmd::List, :cask do
  it "lists the installed Casks in a pretty fashion" do
    casks = %w[local-caffeine local-transmission].map { |c| Cask::CaskLoader.load(c) }

    casks.each do |c|
      InstallHelper.install_with_caskfile(c)
    end

    expect {
      described_class.run
    }.to output(<<~EOS).to_stdout
      local-caffeine
      local-transmission
    EOS
  end

  it "lists oneline" do
    casks = %w[
      local-caffeine
      third-party/tap/third-party-cask
      local-transmission
    ].map { |c| Cask::CaskLoader.load(c) }

    casks.each do |c|
      InstallHelper.install_with_caskfile(c)
    end

    expect {
      described_class.run("-1")
    }.to output(<<~EOS).to_stdout
      local-caffeine
      local-transmission
      third-party-cask
    EOS
  end

  it "lists full names" do
    casks = %w[
      local-caffeine
      third-party/tap/third-party-cask
      local-transmission
    ].map { |c| Cask::CaskLoader.load(c) }

    casks.each do |c|
      InstallHelper.install_with_caskfile(c)
    end

    expect {
      described_class.run("--full-name")
    }.to output(<<~EOS).to_stdout
      local-caffeine
      local-transmission
      third-party/tap/third-party-cask
    EOS
  end

  describe "lists versions" do
    let(:casks) { ["local-caffeine", "local-transmission"] }
    let(:expected_output) {
      <<~EOS
        local-caffeine 1.2.3
        local-transmission 2.61
      EOS
    }

    before do
      casks.map(&Cask::CaskLoader.method(:load)).each(&InstallHelper.method(:install_with_caskfile))
    end

    it "of all installed Casks" do
      expect {
        described_class.run("--versions")
      }.to output(expected_output).to_stdout
    end

    it "of given Casks" do
      expect {
        described_class.run("--versions", "local-caffeine", "local-transmission")
      }.to output(expected_output).to_stdout
    end
  end

  describe "lists json" do
    let(:casks) {
      ["local-caffeine", "local-transmission", "multiple-versions", "with-languages",
       "third-party/tap/third-party-cask"]
    }
    let(:expected_output) {
      <<~EOS
        [
          {
            "token": "local-caffeine",
            "full_token": "local-caffeine",
            "tap": "homebrew/cask",
            "name": [

            ],
            "desc": null,
            "homepage": "https://brew.sh/",
            "url": "file://#{TEST_FIXTURE_DIR}/cask/caffeine.zip",
            "appcast": null,
            "version": "1.2.3",
            "versions": {
            },
            "installed": "1.2.3",
            "outdated": false,
            "sha256": "67cdb8a02803ef37fdbf7e0be205863172e41a561ca446cd84f0d7ab35a99d94",
            "artifacts": [
              {
                "app": [
                  "Caffeine.app"
                ]
              },
              {
                "zap": [
                  {
                    "trash": "#{TEST_FIXTURE_DIR}/cask/caffeine/org.example.caffeine.plist"
                  }
                ]
              }
            ],
            "caveats": null,
            "depends_on": {
            },
            "conflicts_with": null,
            "container": null,
            "auto_updates": null,
            "tap_git_head": null,
            "languages": [

            ]
          },
          {
            "token": "local-transmission",
            "full_token": "local-transmission",
            "tap": "homebrew/cask",
            "name": [
              "Transmission"
            ],
            "desc": "BitTorrent client",
            "homepage": "https://transmissionbt.com/",
            "url": "file://#{TEST_FIXTURE_DIR}/cask/transmission-2.61.dmg",
            "appcast": null,
            "version": "2.61",
            "versions": {
            },
            "installed": "2.61",
            "outdated": false,
            "sha256": "e44ffa103fbf83f55c8d0b1bea309a43b2880798dae8620b1ee8da5e1095ec68",
            "artifacts": [
              {
                "app": [
                  "Transmission.app"
                ]
              }
            ],
            "caveats": null,
            "depends_on": {
            },
            "conflicts_with": null,
            "container": null,
            "auto_updates": null,
            "tap_git_head": null,
            "languages": [

            ]
          },
          {
            "token": "multiple-versions",
            "full_token": "multiple-versions",
            "tap": "homebrew/cask",
            "name": [

            ],
            "desc": null,
            "homepage": "https://brew.sh/",
            "url": "file://#{TEST_FIXTURE_DIR}/cask/caffeine/darwin-arm64/1.2.3/arm.zip",
            "appcast": null,
            "version": "1.2.3",
            "versions": {
              "big_sur": "1.2.0",
              "catalina": "1.0.0",
              "mojave": "1.0.0"
            },
            "installed": "1.2.3",
            "outdated": false,
            "sha256": "67cdb8a02803ef37fdbf7e0be205863172e41a561ca446cd84f0d7ab35a99d94",
            "artifacts": [
              {
                "app": [
                  "Caffeine.app"
                ]
              }
            ],
            "caveats": null,
            "depends_on": {
            },
            "conflicts_with": null,
            "container": null,
            "auto_updates": null,
            "tap_git_head": null,
            "languages": [

            ]
          },
          {
            "token": "third-party-cask",
            "full_token": "third-party/tap/third-party-cask",
            "tap": "third-party/tap",
            "name": [

            ],
            "desc": null,
            "homepage": "https://brew.sh/",
            "url": "https://brew.sh/ThirdParty.dmg",
            "appcast": null,
            "version": "1.2.3",
            "versions": {
            },
            "installed": "1.2.3",
            "outdated": false,
            "sha256": "8c62a2b791cf5f0da6066a0a4b6e85f62949cd60975da062df44adf887f4370b",
            "artifacts": [
              {
                "app": [
                  "ThirdParty.app"
                ]
              }
            ],
            "caveats": null,
            "depends_on": {
            },
            "conflicts_with": null,
            "container": null,
            "auto_updates": null,
            "tap_git_head": null,
            "languages": [

            ]
          },
          {
            "token": "with-languages",
            "full_token": "with-languages",
            "tap": "homebrew/cask",
            "name": [

            ],
            "desc": null,
            "homepage": "https://brew.sh/",
            "url": "file://#{TEST_FIXTURE_DIR}/cask/caffeine.zip",
            "appcast": null,
            "version": "1.2.3",
            "versions": {
            },
            "installed": "1.2.3",
            "outdated": false,
            "sha256": "xyz789",
            "artifacts": [
              {
                "app": [
                  "Caffeine.app"
                ]
              }
            ],
            "caveats": null,
            "depends_on": {
            },
            "conflicts_with": null,
            "container": null,
            "auto_updates": null,
            "tap_git_head": null,
            "languages": [
              "zh",
              "en-US"
            ]
          }
        ]
      EOS
    }
    let!(:original_macos_version) { MacOS.full_version.to_s }

    before do
      # Use a more limited symbols list to shorten the variations hash
      symbols = {
        monterey: "12",
        big_sur:  "11",
        catalina: "10.15",
        mojave:   "10.14",
      }
      stub_const("MacOSVersions::SYMBOLS", symbols)

      # For consistency, always run on Monterey and ARM
      MacOS.full_version = "12"
      allow(Hardware::CPU).to receive(:type).and_return(:arm)

      casks.map(&Cask::CaskLoader.method(:load)).each(&InstallHelper.method(:install_with_caskfile))
    end

    after do
      MacOS.full_version = original_macos_version
    end

    it "of all installed Casks" do
      expect {
        described_class.run("--json")
      }.to output(expected_output).to_stdout
    end

    it "of given Casks" do
      expect {
        described_class.run("--json", "local-caffeine", "local-transmission", "multiple-versions",
                            "third-party/tap/third-party-cask", "with-languages")
      }.to output(expected_output).to_stdout
    end
  end

  describe "given a set of installed Casks" do
    let(:caffeine) { Cask::CaskLoader.load(cask_path("local-caffeine")) }
    let(:transmission) { Cask::CaskLoader.load(cask_path("local-transmission")) }
    let(:casks) { [caffeine, transmission] }

    it "lists the installed files for those Casks" do
      casks.each(&InstallHelper.method(:install_without_artifacts_with_caskfile))

      transmission.artifacts.select { |a| a.is_a?(Cask::Artifact::App) }.each do |artifact|
        artifact.install_phase(command: NeverSudoSystemCommand, force: false)
      end

      expect {
        described_class.run("local-transmission", "local-caffeine")
      }.to output(<<~EOS).to_stdout
        ==> App
        #{transmission.config.appdir.join("Transmission.app")} (#{transmission.config.appdir.join("Transmission.app").abv})
        ==> App
        Missing App: #{caffeine.config.appdir.join("Caffeine.app")}
      EOS
    end
  end
end

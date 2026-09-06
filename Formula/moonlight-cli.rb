# Homebrew formula for the Moonlight CLI.
#
# Named moonlight-cli because homebrew/cask already ships "moonlight"
# (the game-streaming app). The installed command is still `moonlight`.
#
#   brew tap moonlight-architecture/moonlight https://github.com/moonlight-architecture/setup-script
#   brew trust --formula moonlight-architecture/moonlight/moonlight-cli
#   brew install --formula moonlight-architecture/moonlight/moonlight-cli

class MoonlightCli < Formula
  desc "CLI to create and run Moonlight Spring Boot apps"
  homepage "https://github.com/moonlight-architecture/setup-script"
  url "https://github.com/moonlight-architecture/setup-script/archive/refs/tags/v0.0.3.tar.gz"
  sha256 :no_check
  license "MIT"
  version "0.0.3"
  head "https://github.com/moonlight-architecture/setup-script.git", branch: "main"

  depends_on "git"
  depends_on "openjdk@25"

  uses_from_macos "curl"

  def install
    bin.install "moonlight.sh" => "moonlight"
  end

  def caveats
    <<~EOS
      The command is `moonlight`. This formula is named moonlight-cli because
      Homebrew already has a "moonlight" cask (game streaming).

      If `moonlight` launches a desktop app, uninstall that cask first:
        brew uninstall --cask moonlight

      Java 25 comes from keg-only openjdk@25; this CLI finds it automatically.

      Upgrade:    brew upgrade moonlight-cli
      Uninstall:  brew uninstall moonlight-cli
    EOS
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/moonlight version")
    assert_match "Moonlight CLI", shell_output("#{bin}/moonlight help")
  end
end

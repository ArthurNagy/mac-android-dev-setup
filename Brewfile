# Brewfile: mobile (Android / Kotlin Multiplatform / iOS) development on Apple silicon.
# Tested with Homebrew 7 on macOS 27 (Golden Gate).
#
#   brew bundle install --no-upgrade          install what is missing (setup-mac.sh does this)
#   brew bundle check --no-upgrade --verbose  list what is missing
#   brew bundle cleanup </dev/null            list installed packages NOT in this file (exits 1 if any).
#                                             Without the redirect it offers to UNINSTALL them all,
#                                             and a single 'y' keypress does it.
#
# Expect a password prompt: mas (Xcode) and pkg-based casks such as wireshark-app use sudo.
# Third-party taps must be trusted in Homebrew 7: `tap "owner/repo", trusted: true`.

# --- GNU userland (put first on PATH by zsh/mac-android-dev.zsh) ------------------
brew "coreutils"        # GNU core utilities
brew "findutils"        # GNU find, locate, updatedb, xargs
brew "gnu-tar"          # GNU tar
brew "gnu-sed"          # GNU sed
brew "gawk"             # GNU awk
brew "gnu-getopt"       # GNU getopt (keg-only; the zsh config adds its bin/ to PATH)
brew "grep"             # GNU grep

# --- Essentials ----------------------------------------------------------------------
brew "git"
brew "wget"
# No "curl"/"lsof": both are keg-only (macOS ships them), so they never reach PATH.
brew "tree"
brew "htop"
brew "fastfetch"        # System info (neofetch was disabled and removed from Homebrew)
brew "mas"              # Mac App Store CLI

# --- Modern CLI replacements ---------------------------------------------------------
brew "bat"              # cat with syntax highlighting
brew "eza"              # ls replacement (maintained fork of exa)
brew "fd"               # find replacement (use as `fd`, not aliased to find)
brew "ripgrep"          # grep replacement (use as `rg`, not aliased to grep)
brew "fzf"              # Fuzzy finder
brew "git-delta"        # Better git diff (formula was renamed from "delta")

# --- Development tools ---------------------------------------------------------------
brew "neovim"
brew "tmux"
brew "node"
brew "python"           # Current Homebrew Python (3.14 in Sept 2026); was pinned to 3.11
brew "jq"
brew "gh"               # GitHub CLI
brew "shellcheck"       # Lints the scripts in this repo

# --- Android / mobile ------------------------------------------------------------------
cask "android-cli"      # Google's Android CLI (`android`): replaces sdkmanager
                        # (`android sdk ...`), manages emulators, `android update`
brew "scrcpy"           # Android screen mirroring
brew "adb-enhanced"     # Better ADB
brew "bundletool"       # Build/inspect .aab app bundles
brew "apktool"          # Decode/rebuild APKs
brew "jadx"             # Dex to Java decompiler
cask "jetbrains-toolbox" # Installs Android Studio into ~/Applications
mas "Xcode", id: 497799835   # mas 7 asks for your password to install

# --- Network tools ---------------------------------------------------------------------
brew "nmap"             # also provides `ncat`
brew "socat"
# No "netcat": GNU netcat 0.7 (2004) would shadow Apple's nc, which supports -U/-X/-x (proxies).
brew "mtr"
cask "wireshark-app"    # Renamed from "wireshark". Installs the ChmodBPF launch daemon via sudo;
                        # on a managed Mac, or for CLI only, use brew "wireshark" (tshark) instead

# --- System monitoring -----------------------------------------------------------------
brew "glances"
brew "duf"              # df replacement
brew "dust"             # du replacement
brew "procs"            # ps replacement

# --- Containers (pick one) ---------------------------------------------------------------
# OrbStack is free for personal use only; work use needs a paid licence.
# Colima + the docker CLI is the fully open-source alternative.
cask "orbstack"
# brew "colima"
# brew "docker"

# --- Security --------------------------------------------------------------------------
brew "gnupg"
# No "openssh": it would shadow Apple's ssh, which supports `UseKeychain` and
# `ssh-add --apple-use-keychain` (what GitHub's macOS instructions rely on).
# No explicit "openssl": it now resolves to openssl@4 and every tool that needs
# OpenSSL already depends on the version it was built against.

# --- Shell -------------------------------------------------------------------------------
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
cask "font-jetbrains-mono-nerd-font"

# --- GUI apps ----------------------------------------------------------------------------
cask "ghostty"          # Terminal (replaces iTerm2). Adopts an existing /Applications/Ghostty.app
cask "visual-studio-code"
cask "hiddenbar"        # Menu bar management (needs >= 1.11.1 on macOS 27)
cask "appcleaner"       # Proper app uninstaller
cask "google-chrome"
brew "dockutil"         # Used by `cleanup-apps.sh --reset-dock`

# Battery: AlDente is no longer installed. macOS 26.4+ has a native charge limit
# (System Settings > Battery > Charging (i) > Charge Limit, 80-100%).
# Add `cask "aldente"` back only for limits below 80%, sailing mode or heat protection.

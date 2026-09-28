#!/bin/bash
#
# Set up an Apple silicon Mac (macOS 15-27) for Android / Kotlin Multiplatform / iOS work.
#
#   ./setup-mac.sh                tools + shell config, then asks about tweaks and app cleanup
#   ./setup-mac.sh --all          also run macos-tweaks.sh and cleanup-apps.sh (they still ask per change)
#   ./setup-mac.sh --shell        only (re)install the managed zsh config
#   ./setup-mac.sh --no-system    never run macos-tweaks.sh / cleanup-apps.sh
#   ./setup-mac.sh -n|--dry-run   print what would happen (same as DRY_RUN=1)
#
# Safe to re-run: every step checks what is already there. Exits non-zero if a step failed.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; }

SYSTEM=ask; ONLY_SHELL=0
for arg in "$@"; do
    case "$arg" in
        --all)        SYSTEM=yes ;;
        --no-system)  SYSTEM=no ;;
        --shell)      ONLY_SHELL=1 ;;
        -n|--dry-run) enable_dry_run ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage; die "Unknown option: $arg" ;;
    esac
done

require_apple_silicon
require_macos 15
is_dry_run && print_warning "Dry run: nothing will be changed."

BREWFILE="$SCRIPT_DIR/Brewfile"
MANAGED_SRC="$SCRIPT_DIR/zsh/mac-android-dev.zsh"
MANAGED_DIR="$HOME/.config/mac-android-dev-setup"
MANAGED_DST="$MANAGED_DIR/zshrc.zsh"
BLOCK_BEGIN="# >>> mac-android-dev-setup >>>"
BLOCK_END="# <<< mac-android-dev-setup <<<"

install_shell_config() {
    print_step "Shell configuration"
    run mkdir -p "$MANAGED_DIR" || { FAILURES=$((FAILURES + 1)); print_warning "Could not create $MANAGED_DIR"; return 1; }
    if run cp "$MANAGED_SRC" "$MANAGED_DST"; then
        is_dry_run || print_success "Installed $MANAGED_DST"
    else
        FAILURES=$((FAILURES + 1)); print_warning "Could not copy the managed config"; return 1
    fi
    if grep -qF "$BLOCK_BEGIN" "$HOME/.zshrc" 2>/dev/null; then
        print_success "~/.zshrc already sources it"
    elif is_dry_run; then
        run "back up ~/.zshrc, then append the mac-android-dev-setup source block"
    else
        local bk=""
        bk="$HOME/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
        if [[ -e "$HOME/.zshrc" ]]; then
            cp "$HOME/.zshrc" "$bk" || { FAILURES=$((FAILURES + 1)); print_warning "Could not back up ~/.zshrc; left it unchanged."; return 1; }
        fi
        if cat >> "$HOME/.zshrc" <<EOF

$BLOCK_BEGIN
# Managed by $SCRIPT_DIR (re-run setup-mac.sh --shell to update).
[[ -r "\$HOME/.config/mac-android-dev-setup/zshrc.zsh" ]] && source "\$HOME/.config/mac-android-dev-setup/zshrc.zsh"
$BLOCK_END
EOF
        then
            print_success "Added the managed block to the end of ~/.zshrc${bk:+ (backup: $bk)}"
        else
            FAILURES=$((FAILURES + 1)); print_warning "Could not write to ~/.zshrc"; return 1
        fi
    fi
    # The 2025 version of this script wrote aliases and PATH lines straight into
    # ~/.zshrc. Only line numbers are printed: ~/.zshrc can hold secrets.
    local lines
    lines="$(grep -nE "$LEGACY_ZSHRC_RE" "$HOME/.zshrc" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
    if [[ -n "$lines" ]]; then
        print_warning "~/.zshrc still contains the 2025 generated block (lines: $lines)."
        print_info "Delete the Homebrew/GNU PATH, ANDROID_HOME, JAVA_HOME and alias lines of that block by hand;"
        print_info "the managed config replaces them. Keep your own exports and secrets. See README."
    fi
}

if [[ $ONLY_SHELL == 1 ]]; then
    install_shell_config
    is_dry_run || print_success "Open a new terminal (or: source ~/.zshrc)."
    (( FAILURES == 0 )); exit
fi

print_step "Setting up $(sw_vers -productName) $(macos_version) on $(sysctl -n machdep.cpu.brand_string)"

# --- Command Line Tools ---------------------------------------------------------------------------
print_step "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    print_success "Installed ($(xcode-select -p))"
else
    run xcode-select --install
    is_dry_run || die "Finish the Command Line Tools installer, then run this script again."
fi

# --- Homebrew -------------------------------------------------------------------------------------
print_step "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    if is_dry_run; then
        run "download and run the Homebrew installer (https://brew.sh)"
    else
        # A failed download must not run an empty script and "succeed".
        inst="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            || die "Could not download the Homebrew installer (network or proxy?)."
        /bin/bash -c "$inst" || die "Homebrew installation failed."
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
if [[ -x /opt/homebrew/bin/brew ]] && ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
    # shellcheck disable=SC2016  # written to ~/.zprofile unexpanded, on purpose
    if is_dry_run; then run 'append eval "$(/opt/homebrew/bin/brew shellenv)" to ~/.zprofile'
    else printf '\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> "$HOME/.zprofile"; fi
fi
command -v brew >/dev/null 2>&1 && print_success "$(brew --version | head -1)"

# --- Packages -------------------------------------------------------------------------------------
print_step "Packages from the Brewfile"
if command -v brew >/dev/null 2>&1; then
    print_info "Expect a password prompt: mas (Xcode) and pkg-based casks such as wireshark-app install with sudo."
    try brew update
    # --no-upgrade: install what is missing, do not force-upgrade everything else.
    # Existing apps (e.g. a manually installed Ghostty) are adopted, not reinstalled.
    if ! run brew bundle install --no-upgrade --file="$BREWFILE"; then
        FAILURES=$((FAILURES + 1))
        print_warning "Some Brewfile entries failed; the rest was installed. See: brew bundle check --no-upgrade --verbose --file=\"$BREWFILE\""
    fi
elif is_dry_run; then
    run brew bundle install --no-upgrade --file="$BREWFILE"
else
    FAILURES=$((FAILURES + 1))
    print_warning "Homebrew is not available; Brewfile packages were NOT installed."
fi

# --- Shell ----------------------------------------------------------------------------------------
print_step "Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_success "Already installed"
elif is_dry_run; then
    run "install Oh My Zsh (unattended, keeping ~/.zshrc)"
else
    # KEEP_ZSHRC=yes: never replace an existing ~/.zshrc.
    if omz="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
        RUNZSH=no KEEP_ZSHRC=yes sh -c "$omz" "" --unattended \
            || { FAILURES=$((FAILURES + 1)); print_warning "Oh My Zsh installation failed (the managed config works without it)."; }
    else
        FAILURES=$((FAILURES + 1)); print_warning "Could not download the Oh My Zsh installer (the managed config works without it)."
    fi
fi
if [[ -d "$HOME/.oh-my-zsh" ]] && ! grep -qs 'oh-my-zsh.sh' "$HOME/.zshrc"; then
    print_warning "Oh My Zsh is installed but ~/.zshrc does not load it (the installer keeps an existing ~/.zshrc)."
    print_info "Add above the managed block: export ZSH=\"\$HOME/.oh-my-zsh\"; plugins=(git macos); source \$ZSH/oh-my-zsh.sh"
fi
install_shell_config

# --- Android CLI and SDK baseline -------------------------------------------------------------------
print_step "Android CLI and SDK"
ANDROID_BIN=""
for c in "$(command -v android 2>/dev/null || true)" /opt/homebrew/bin/android \
         "${ANDROID_HOME:-$HOME/Library/Android/sdk}/cmdline-tools/latest/bin/android"; do
    [[ -n "$c" && -x "$c" ]] && { ANDROID_BIN="$c"; break; }
done
if [[ -n "$ANDROID_BIN" ]]; then
    try "$ANDROID_BIN" update
    is_dry_run || print_success "Android CLI $("$ANDROID_BIN" info version 2>/dev/null | tail -1)"
    SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    missing=""
    [[ -d "$SDK/platform-tools" ]] || missing="$missing platform-tools"
    [[ -d "$SDK/emulator" ]] || missing="$missing emulator"
    [[ -d "$SDK/cmdline-tools/latest" ]] || missing="$missing cmdline-tools/latest"
    if [[ -n "$missing" ]]; then
        # shellcheck disable=SC2086  # word splitting of the package list is intended
        try "$ANDROID_BIN" --sdk="$SDK" sdk install $missing
    else
        print_success "SDK baseline present in $SDK (platforms and build-tools are installed per project by Gradle)"
    fi
elif is_dry_run; then
    run "android update, then android sdk install platform-tools emulator cmdline-tools/latest (after brew installs android-cli)"
else
    FAILURES=$((FAILURES + 1))
    print_warning "Android CLI not found; install it with: brew install --cask android-cli"
fi

# --- Optional system changes ----------------------------------------------------------------------------
# In a dry run the child script runs too: it honours DRY_RUN and previews its own changes.
run_system_script() {   # $1 script, $2 question
    case "$SYSTEM" in
        yes) ;;
        no)  return 0 ;;
        ask) is_dry_run || confirm "$2" || { print_info "Skipped $1"; return 0; } ;;
    esac
    # The child scripts still ask before each change; --all only skips this question.
    bash "$SCRIPT_DIR/$1" || { FAILURES=$((FAILURES + 1)); print_warning "Failed (continuing): $1"; }
}
run_system_script macos-tweaks.sh "Apply macOS tweaks? (Dock, Finder, keyboard, trackpad, clock, reduce motion/transparency; it asks again before turning off Handoff/Universal Clipboard, classic Siri, crash dialogs and App Store auto-updates, and before power settings. Previous values are recorded.)"
run_system_script cleanup-apps.sh "Offer to trash GarageBand/iMovie/Numbers/Pages and show dev-cache disk usage?"

# --- Done ---------------------------------------------------------------------------------------------
if is_dry_run; then
    print_success "Dry run finished; nothing was changed."
elif (( FAILURES > 0 )); then
    print_warning "$FAILURES step(s) failed; see the warnings above. Fix them and re-run (it is safe to re-run)."
else
    print_success "Setup complete. Open a new terminal (or: source ~/.zshrc)."
fi
cat <<'EOF'
Next steps:
  1. JetBrains Toolbox: install Android Studio (lands in ~/Applications).
  2. Xcode: open it once to accept the licence and install an iOS simulator runtime.
  3. Rectangle: grant Accessibility access and pick shortcuts.
  4. Run ./post-update-check.sh to verify everything.
EOF
(( FAILURES == 0 ))

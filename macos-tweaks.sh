#!/bin/bash
#
# macOS tweaks for a lean, Linux-like developer Mac (Apple silicon, macOS 15-27).
#
#   ./macos-tweaks.sh               apply (asks before the optional sections)
#   ./macos-tweaks.sh -n|--dry-run  print what would change, change nothing (same as DRY_RUN=1)
#   ./macos-tweaks.sh -h|--help     show this help
#
# Before writing, every key's previous value is recorded in
# ~/.mac-android-dev-setup/backups/<timestamp>-tweaks/keys.tsv (the first run
# is also kept as backups/original), so `./restore-defaults.sh --from-backup DIR`
# puts back exactly these keys.
#
# Removed for macOS 26/27 because they did nothing or did harm (see README):
# Spotlight off/on (forced a full reindex every run), photoanalysisd key,
# launchctl disable of Siri/Spotlight agents, iCloud daemon bootout,
# apsd/Bluetooth/location/ambient-light kill switches, `airport`, Intel-only
# pmset keys, tcpkeepalive 0 (breaks Find My while asleep), killall Terminal.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//'; }
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) enable_dry_run ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage; die "Unknown option: $arg" ;;
    esac
done

require_apple_silicon
require_macos 15
is_dry_run && print_warning "Dry run: nothing will be changed."

# --- Backup ------------------------------------------------------------------------
BACKUP_DIR="$(new_backup_dir tweaks)"
KEYS_FILE=""
if ! is_dry_run; then
    KEYS_FILE="$BACKUP_DIR/keys.tsv"
    : > "$KEYS_FILE"
    pmset -g custom > "$BACKUP_DIR/pmset-custom.txt" 2>/dev/null || true
fi
print_step "Recording previous values in $BACKUP_DIR"

# --- Dock --------------------------------------------------------------------------
print_step "Dock"
tweak user com.apple.dock autohide bool true
tweak user com.apple.dock autohide-delay float 0
tweak user com.apple.dock autohide-time-modifier float 0.5
tweak user com.apple.dock orientation string left
tweak user com.apple.dock tilesize int 48
tweak user com.apple.dock show-recents bool false

# --- Finder ------------------------------------------------------------------------
print_step "Finder"
tweak user com.apple.finder ShowPathbar bool true
tweak user com.apple.finder ShowStatusBar bool true
tweak user com.apple.finder FXDefaultSearchScope string SCcf   # search the current folder
tweak user com.apple.finder FXEnableExtensionChangeWarning bool false
tweak user NSGlobalDomain AppleShowAllExtensions bool true
tweak user com.apple.desktopservices DSDontWriteNetworkStores bool true   # no .DS_Store on network shares

# --- Keyboard & text input ------------------------------------------------------------
print_step "Keyboard and text input"
tweak user NSGlobalDomain KeyRepeat int 2
tweak user NSGlobalDomain InitialKeyRepeat int 15
tweak user NSGlobalDomain ApplePressAndHoldEnabled bool false
tweak user NSGlobalDomain NSAutomaticCapitalizationEnabled bool false
tweak user NSGlobalDomain NSAutomaticDashSubstitutionEnabled bool false
tweak user NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled bool false
tweak user NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled bool false
tweak user NSGlobalDomain NSAutomaticSpellingCorrectionEnabled bool false

# --- Trackpad: tap to click ------------------------------------------------------------
# The built-in trackpad reads com.apple.AppleMultitouchTrackpad and the per-host
# tapBehavior; the 2025 script only set the Bluetooth Magic Trackpad domain.
print_step "Trackpad (tap to click, built-in and Magic Trackpad)"
tweak user com.apple.AppleMultitouchTrackpad Clicking bool true
tweak user com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking bool true
tweak host NSGlobalDomain com.apple.mouse.tapBehavior int 1
tweak user NSGlobalDomain com.apple.mouse.tapBehavior int 1

# --- Menu bar clock ----------------------------------------------------------------------
# Since macOS 11 the clock ignores DateFormat; it reads these keys instead.
print_step "Menu bar clock (weekday, 24-hour, seconds)"
tweak user com.apple.menuextra.clock ShowDayOfWeek bool true
tweak user com.apple.menuextra.clock Show24Hour bool true
tweak user com.apple.menuextra.clock ShowSeconds bool true

# --- Activity Monitor --------------------------------------------------------------------
print_step "Activity Monitor"
tweak user com.apple.ActivityMonitor OpenMainWindow bool true
tweak user com.apple.ActivityMonitor IconType int 5
tweak user com.apple.ActivityMonitor SortColumn string CPUUsage
tweak user com.apple.ActivityMonitor SortDirection int 0

# --- Less background chatter (asks first: these turn features off) ----------------------
print_step "Handoff, classic Siri, crash dialogs, Time Machine prompts, iCloud default save, App Store auto-updates"
print_info "Turning off Handoff also turns off Universal Clipboard. App Store apps then update via 'mas upgrade'."
if is_dry_run || confirm "Turn these off?"; then
    tweak host com.apple.coreservices.useractivityd ActivityAdvertisingAllowed bool false
    tweak host com.apple.coreservices.useractivityd ActivityReceivingAllowed bool false
    tweak user com.apple.assistant.support "Assistant Enabled" bool false
    tweak user com.apple.Siri StatusMenuVisible bool false
    tweak user com.apple.Siri UserHasDeclinedEnable bool true
    tweak user com.apple.CrashReporter DialogType string none
    tweak user com.apple.TimeMachine DoNotOfferNewDisksForBackup bool true
    tweak user NSGlobalDomain NSDocumentSaveNewDocumentsToCloud bool false
    tweak user com.apple.commerce AutoUpdate bool false
else
    print_info "Skipped."
fi

# --- Animations and transparency (Liquid Glass) ------------------------------------------
# The two main compositor levers on macOS 26/27. The domain is protected: the
# write fails unless your terminal app has Full Disk Access.
print_step "Reduce transparency and reduce motion"
ua_ok=1
set_pref user com.apple.universalaccess reduceTransparency bool true || ua_ok=0
set_pref user com.apple.universalaccess reduceMotion bool true || ua_ok=0
if is_dry_run; then
    :
elif [[ $ua_ok == 1 ]]; then
    print_success "Written. If the menu bar or Dock still look glassy, toggle them once in System Settings > Accessibility > Display / Motion."
else
    print_warning "Could not write com.apple.universalaccess (your terminal app lacks Full Disk Access)."
    print_info "Set them by hand: System Settings > Accessibility > Display > Reduce transparency,"
    print_info "and System Settings > Accessibility > Motion > Reduce motion."
fi

# --- Power (admin) ---------------------------------------------------------------------------
# Only settings that exist on Apple silicon. hibernatemode 3, standby 1 and
# disksleep 10 are already the laptop defaults and are no longer written.
print_step "Power settings (needs admin)"
if is_dry_run || confirm "Set display sleep 15 min, sleep 30 min, Power Nap off, no wake for network access?"; then
    if ensure_sudo; then
        try sudo pmset -a displaysleep 15
        try sudo pmset -a sleep 30
        try sudo pmset -a powernap 0
        try sudo pmset -a womp 0           # "Wake for network access"
        try sudo pmset -a tcpkeepalive 1   # default; the 2025 script set 0, which breaks Find My Mac while asleep
    fi
else
    print_info "Skipped."
fi

# --- Keep the very first snapshot ---------------------------------------------------------------
# Later runs record already-tweaked values; backups/original is the pre-tweak state.
if ! is_dry_run && [[ ! -d "$BACKUP_ROOT/original" ]]; then
    cp -R "$BACKUP_DIR" "$BACKUP_ROOT/original"
fi

# --- Restart affected UI processes ------------------------------------------------------------
# Never kill the terminal that is running this script.
print_step "Restarting Dock, Finder, SystemUIServer and ControlCenter"
for app in Dock Finder SystemUIServer ControlCenter; do
    if is_dry_run; then run killall "$app"; else killall "$app" >/dev/null 2>&1 || true; fi
done

# --- Things a script cannot (or should not) change on macOS 27 ------------------------------
cat <<'EOF'

Manual steps (System Settings), recommended on macOS 27:
  1. Spotlight stays ON: Siri AI, Mail and Xcode search need its index. To keep
     build output out of it, add your dev folders under Spotlight > Search Privacy
     (e.g. ~/Development, ~/Library/Android; hidden folders like ~/.gradle are never indexed).
  2. Siri AI / Apple Intelligence: Siri > Turn Off Siri (or use Siri Classic),
     and Apple Intelligence & Siri > Apple Intelligence off if you do not use it.
  3. Battery: Battery > Charging (i) > Charge Limit (native since macOS 26.4;
     AlDente is not needed for an 80-100% limit).
  4. External monitor feels laggy? Displays > (monitor) > Refresh Rate: pick a
     fixed rate instead of "Variable" (adaptive sync).
  5. iCloud daemons cannot be stopped with SIP on: turn off the iCloud services
     you do not use under Apple Account > iCloud.
  6. After a macOS upgrade, leave the Mac on power overnight once so Spotlight
     and media analysis can finish; then run ./post-update-check.sh.

EOF
if is_dry_run; then
    print_success "Dry run finished; nothing was changed."
else
    print_success "Tweaks applied. Previous values: $BACKUP_DIR/keys.tsv"
    print_info "Keyboard repeat and tap-to-click fully apply after logging out and back in."
fi
(( FAILURES == 0 ))

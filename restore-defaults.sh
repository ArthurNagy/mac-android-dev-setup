#!/bin/bash
#
# Undo macos-tweaks.sh (this version and the 2025 ones).
#
#   ./restore-defaults.sh                    delete every key the tweaks ever set, so macOS uses its own defaults
#   ./restore-defaults.sh --list-backups     show the snapshots macos-tweaks.sh recorded
#   ./restore-defaults.sh --from-backup DIR  put the tweaked keys back to their values in that snapshot
#   ./restore-defaults.sh -n|--dry-run ...   print what would happen (same as DRY_RUN=1)
#
# Deleting a key (instead of writing a guessed "default" value) is what returns
# a setting to Apple's default. Two optional admin steps ask separately: reset
# power settings (Energy Mode is kept) and clean up 2025 system-level residue.
# Apps removed by cleanup-apps.sh are in the Trash or on the App Store;
# Homebrew packages are not touched.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'; }

MODE=defaults; FROM=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from-backup)
            MODE=backup; FROM="${2:-}"
            [[ -n "$FROM" ]] || { usage; die "--from-backup needs a directory (see --list-backups)"; }
            shift ;;
        --list-backups) MODE=list ;;
        -n|--dry-run)   enable_dry_run ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage; die "Unknown option: $1" ;;
    esac
    shift
done

require_macos 15
is_dry_run && print_warning "Dry run: nothing will be changed."

restart_ui() {
    print_step "Restarting Dock, Finder, SystemUIServer and ControlCenter"
    local app
    for app in Dock Finder SystemUIServer ControlCenter; do
        if is_dry_run; then run killall "$app"; else killall "$app" >/dev/null 2>&1 || true; fi
    done
}

# del DOMAIN KEY... / delh DOMAIN KEY...: delete keys (delh: -currentHost). Missing keys are fine.
del() {
    local domain="$1" key
    shift
    for key in "$@"; do
        if is_dry_run; then run defaults delete "$domain" "$key"; else defaults delete "$domain" "$key" >/dev/null 2>&1 || true; fi
    done
}
delh() {
    local domain="$1" key
    shift
    for key in "$@"; do
        if is_dry_run; then run defaults -currentHost delete "$domain" "$key"; else defaults -currentHost delete "$domain" "$key" >/dev/null 2>&1 || true; fi
    done
}

# --- List snapshots -----------------------------------------------------------------------------
if [[ $MODE == list ]]; then
    if [[ -d "$BACKUP_ROOT/original" ]]; then
        printf '%s\n' "$BACKUP_ROOT/original   <- values before the first run of this version (use this one)"
    fi
    found=0
    for d in "$BACKUP_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        d="${d%/}"
        [[ "$(basename "$d")" == original ]] && continue
        printf '%s\n' "$d"; found=1
    done
    [[ $found == 1 || -d "$BACKUP_ROOT/original" ]] || print_info "No backups yet ($BACKUP_ROOT)."
    print_info "Macs tweaked by the 2025 scripts have no pre-tweak snapshot: use plain ./restore-defaults.sh."
    exit 0
fi

# --- Restore a snapshot ---------------------------------------------------------------------------
if [[ $MODE == backup ]]; then
    [[ -d "$FROM" ]] || die "No such backup: $FROM (see --list-backups)"
    if [[ -f "$FROM/keys.tsv" ]]; then
        n="$(wc -l < "$FROM/keys.tsv" | tr -d ' ')"
        print_step "Restoring $n keys to their values in $FROM (keys that did not exist then are deleted)"
        is_dry_run || confirm "Continue?" || die "Cancelled."
        tab="$(printf '\t')"
        while IFS="$tab" read -r scope domain key type value; do
            [[ -n "$domain" ]] || continue
            host=""; [[ "$scope" == host ]] && host="-currentHost"
            case "$type" in
                -)       if is_dry_run; then run defaults ${host:+"$host"} delete "$domain" "$key"
                         else defaults ${host:+"$host"} delete "$domain" "$key" >/dev/null 2>&1 || true; fi ;;
                boolean) if [[ "$value" == 1 ]]; then value=true; else value=false; fi
                         try defaults ${host:+"$host"} write "$domain" "$key" -bool "$value" ;;
                integer) try defaults ${host:+"$host"} write "$domain" "$key" -int "$value" ;;
                float)   try defaults ${host:+"$host"} write "$domain" "$key" -float "$value" ;;
                string)  try defaults ${host:+"$host"} write "$domain" "$key" -string "$value" ;;
                *)       print_info "Skipped $domain $key (type $type; restore it by hand)" ;;
            esac
        done < "$FROM/keys.tsv"
    else
        # Whole-domain snapshots (e.g. the Dock backup made by cleanup-apps.sh --reset-dock).
        print_warning "This snapshot has whole domains. Keys in it return to their snapshot values;"
        print_warning "keys created since then are NOT removed (use plain ./restore-defaults.sh for those)."
        for f in "$FROM"/*.plist; do [[ -e "$f" ]] && print_info "$(basename "$f" .plist)"; done
        is_dry_run || confirm "Import these domains?" || die "Cancelled."
        for f in "$FROM"/*.plist; do
            [[ -e "$f" ]] || continue
            try defaults import "$(basename "$f" .plist)" "$f"
        done
    fi
    if [[ -f "$FROM/pmset-custom.txt" ]]; then
        print_info "Power settings at snapshot time (restore with sudo pmset if needed):"
        sed 's/^/    /' "$FROM/pmset-custom.txt"
    fi
    restart_ui
    print_success "Snapshot restored. Log out and back in for keyboard and trackpad settings."
    exit 0
fi

# --- Factory defaults -------------------------------------------------------------------------------
print_warning "This deletes every preference the tweak scripts set (Dock, Finder, keyboard, trackpad,"
print_warning "clock, Siri, Handoff, crash dialogs, App Store, animations) so macOS uses its defaults."
is_dry_run || confirm "Continue?" || die "Cancelled."

print_step "Dock, Finder, keyboard, text input"
del com.apple.dock autohide autohide-delay autohide-time-modifier orientation tilesize show-recents
del com.apple.finder ShowPathbar ShowStatusBar FXDefaultSearchScope FXEnableExtensionChangeWarning
del com.apple.desktopservices DSDontWriteNetworkStores
del NSGlobalDomain AppleShowAllExtensions KeyRepeat InitialKeyRepeat ApplePressAndHoldEnabled \
    NSAutomaticCapitalizationEnabled NSAutomaticDashSubstitutionEnabled NSAutomaticPeriodSubstitutionEnabled \
    NSAutomaticQuoteSubstitutionEnabled NSAutomaticSpellingCorrectionEnabled \
    NSDocumentSaveNewDocumentsToCloud _HIHideMenuBar com.apple.mouse.tapBehavior

print_step "Trackpad, menu bar clock, Activity Monitor"
del com.apple.AppleMultitouchTrackpad Clicking
del com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking
delh NSGlobalDomain com.apple.mouse.tapBehavior
del com.apple.menuextra.clock DateFormat ShowDayOfWeek Show24Hour ShowSeconds
del com.apple.ActivityMonitor OpenMainWindow IconType SortColumn SortDirection

print_step "Siri, Handoff, crash dialogs, Time Machine prompts, App Store updates"
del com.apple.assistant.support "Assistant Enabled"
del com.apple.Siri StatusMenuVisible UserHasDeclinedEnable
delh com.apple.coreservices.useractivityd ActivityAdvertisingAllowed ActivityReceivingAllowed
del com.apple.CrashReporter DialogType
del com.apple.TimeMachine DoNotOfferNewDisksForBackup
del com.apple.commerce AutoUpdate

print_step "Keys written by the 2025 versions of the scripts"
del com.apple.photoanalysisd enabled
del com.apple.gamed Disabled
del com.apple.NetworkBrowser DisableAirDrop
del com.apple.appstore WebKitAutomaticPushNotificationEnabled
del com.apple.appstoreagent AutomaticCheckEnabled
del com.apple.SoftwareUpdate AutomaticCheckEnabled AutomaticDownload ScheduleFrequency
del com.apple.SubmitDiagInfo AutoSubmit
del com.apple.terminal StringEncodings Shell
del com.apple.finder AppleShowAllFiles
del com.apple.screencapture location type disable-shadow
# The 2025 script wrote Handoff keys to a ByHost file without the host UUID.
legacy_handoff="$HOME/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist"
[[ -f "$legacy_handoff" ]] && try rm -f "$legacy_handoff"

print_step "Transparency and motion"
if is_dry_run; then
    run defaults delete com.apple.universalaccess reduceTransparency
    run defaults delete com.apple.universalaccess reduceMotion
else
    ua_ok=1
    for key in reduceTransparency reduceMotion; do
        if defaults read com.apple.universalaccess "$key" >/dev/null 2>&1; then
            defaults delete com.apple.universalaccess "$key" 2>/dev/null || ua_ok=0
        fi
    done
    [[ $ua_ok == 1 ]] || print_warning "No Full Disk Access for this terminal: turn Reduce transparency / Reduce motion off in System Settings > Accessibility."
fi

# Only the agents the 2025 macos-tweaks.sh disabled. com.apple.Siri.agent is
# managed by System Settings > Siri and is left alone.
print_step "launchd overrides from the 2025 scripts (user domain)"
uid="$(id -u)"
disabled="$(launchctl print-disabled "gui/$uid" 2>/dev/null || true)"
for label in com.apple.parsecd com.apple.knowledge-agent com.apple.assistantd; do
    if printf '%s\n' "$disabled" | grep -q "\"$label\" => disabled"; then
        try launchctl enable "gui/$uid/$label" && { is_dry_run || print_success "Re-enabled $label (starts at next login)"; }
    fi
done
print_info "To turn Siri back on, use System Settings > Siri (macOS manages its own agent)."

# --- Admin step 1: power settings ---------------------------------------------------------------------
print_step "Power settings (needs admin)"
# Settings no version of the tweaks ever wrote; they survive the reset.
pm_keep() {
    awk '/^Battery Power/{s="-b"} /^AC Power/{s="-c"} /^UPS Power/{s="-u"}
         s && $1 ~ /^(powermode|lowpowermode|highpowermode|ttyskeepawake|lessbright|networkoversleep|proximitywake|halfdim)$/ {print s, $1, $2}'
}
if is_dry_run || confirm "Reset power settings to this Mac's factory profile (Energy Mode and similar options are kept)?"; then
    if ensure_sudo; then
        pm_before="$(pmset -g custom 2>/dev/null | pm_keep)"
        try sudo pmset restoredefaults
        if ! is_dry_run; then
            pm_after="$(pmset -g custom 2>/dev/null | pm_keep)"
            for src in -b -c -u; do
                args=""
                while read -r s k v; do
                    [[ "$s" == "$src" && -n "$k" ]] || continue
                    printf '%s\n' "$pm_after" | grep -Fqx "$s $k $v" || args="$args $k $v"
                done <<< "$pm_before"
                # shellcheck disable=SC2086  # "key value" pairs are meant to split
                [[ -n "$args" ]] && try sudo pmset "$src" $args
            done
        fi
    fi
else
    print_info "Skipped."
fi

# --- Admin step 2: 2025 system-level residue and Spotlight ------------------------------------------------
print_step "System-level leftovers from the 2025 scripts (needs admin)"
if is_dry_run || confirm "Remove them and re-enable Spotlight if it is off?"; then
    if ensure_sudo; then
        # Spotlight: only if it is actually off. Turning it on starts a full reindex.
        for vol in / /System/Volumes/Data; do
            if mdutil -s "$vol" 2>/dev/null | grep -q "disabled"; then
                print_warning "Re-enabling Spotlight on $vol; indexing will use CPU and disk for a while."
                try sudo mdutil -i on "$vol"
            fi
        done
        for entry in \
            "/Library/Preferences/com.apple.apsd|Enabled" \
            "/Library/Preferences/com.apple.iokit.AmbientLightSensor|Automatic Display Enabled" \
            "/Library/Preferences/com.apple.iokit.AmbientLightSensor|Automatic Keyboard Enabled" \
            "/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd|LocationServicesEnabled"; do
            plist="${entry%%|*}"; key="${entry#*|}"
            if is_dry_run; then run sudo defaults delete "$plist" "$key"
            else sudo defaults delete "$plist" "$key" >/dev/null 2>&1 || true; fi
        done
        if [[ "$(defaults read /Library/Preferences/com.apple.Bluetooth ControllerPowerState 2>/dev/null)" == "0" ]]; then
            try sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 1
        fi
    fi
else
    print_info "Skipped."
fi

restart_ui
if is_dry_run; then
    print_success "Dry run finished; nothing was changed."
else
    print_success "Defaults restored."
    print_info "Log out and back in for keyboard repeat and tap-to-click to settle."
    print_info "Dock items are not changed; if cleanup-apps.sh --reset-dock replaced them, see --list-backups."
fi

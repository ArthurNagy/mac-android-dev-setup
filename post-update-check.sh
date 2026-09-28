#!/bin/bash
#
# Read-only health check for a mobile-dev Mac, meant for after a macOS upgrade
# (e.g. 26 -> 27) or whenever the Mac feels slow. It changes nothing.
#
#   ./post-update-check.sh          quick check (about 10 seconds)
#   ./post-update-check.sh --deep   also scan the last hour of logs for display timing errors
#
# Warnings come with the manual fix. It never tells you to re-run macos-tweaks.sh:
# Spotlight being on and Apple agents running are normal on macOS 26/27.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DEEP=0
for arg in "$@"; do
    case "$arg" in
        --deep) DEEP=1 ;;
        -h|--help) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

ok()   { print_success "$1"; }
warn() { print_warning "$1"; [[ -n "${2:-}" ]] && print_info "fix: $2"; return 0; }
info() { print_info "$1"; }

# cputime_seconds NAME: CPU seconds used by all running processes with that name.
cputime_seconds() {
    ps -Axo time=,comm= 2>/dev/null | awk -v want="$1" '
        { n=$0; sub(/^ *[^ ]+ +/, "", n); sub(/.*\//, "", n) }
        n == want {
            t=$1; d=0
            if (t ~ /-/) { split(t, a, "-"); d=a[1]; t=a[2] }
            k=split(t, p, ":"); s=0
            for (i=1; i<=k; i++) s = s*60 + p[i]
            total += d*86400 + s
        }
        END { printf "%d\n", total }'
}
# cpu_now NAME: current %CPU (ps decaying average) summed over processes with that name.
cpu_now() {
    ps -Axo %cpu=,comm= 2>/dev/null | awk -v want="$1" '
        { n=$0; sub(/^ *[^ ]+ +/, "", n); sub(/.*\//, "", n) } n == want { t += $1 } END { printf "%d\n", t }'
}

boot_epoch="$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')"
now_epoch="$(date +%s)"
uptime_s=$(( now_epoch - boot_epoch ))
(( uptime_s > 0 )) || uptime_s=1
uid="$(id -u)"

# --- System -----------------------------------------------------------------------------------
print_step "System"
info "$(sw_vers -productName) $(macos_version) ($(sw_vers -buildVersion)) on $(sysctl -n machdep.cpu.brand_string), $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
info "Uptime: $(( uptime_s / 3600 )) h $(( uptime_s % 3600 / 60 )) min"
last_os="$(softwareupdate --history 2>/dev/null | grep -E '^macOS ' | tail -1 | sed -E 's/  +/  /g')"
[[ -n "$last_os" ]] && info "Last macOS install: $last_os"
if (( $(macos_major) > TESTED_MACOS_MAJOR )); then
    warn "This macOS is newer than the scripts were tested on ($TESTED_MACOS_MAJOR)." "Preview the tweak scripts with --dry-run first."
fi
if csrutil status 2>/dev/null | grep -q enabled; then ok "System Integrity Protection enabled"
else warn "SIP is not enabled" "Boot to Recovery and run: csrutil enable"; fi
if spctl --status 2>/dev/null | grep -q enabled; then ok "Gatekeeper enabled"
else warn "Gatekeeper assessments are off" "System Settings > Privacy & Security > Allow applications from"; fi

# --- Background work after an upgrade -------------------------------------------------------------
print_step "Background work (CPU time since boot, and right now)"
for proc in mediaanalysisd photoanalysisd mds_stores mds mdworker_shared corespotlightd spotlightknowledged WindowServer; do
    s="$(cputime_seconds "$proc")"
    (( s >= 60 )) || continue
    printf '  %-20s %4d min  (%d%% of a core on average, %d%% now)\n' "$proc" $(( s / 60 )) $(( s * 100 / uptime_s )) "$(cpu_now "$proc")"
done
ma="$(cputime_seconds mediaanalysisd)"; ma_now="$(cpu_now mediaanalysisd)"; ma_pct=$(( ma * 100 / uptime_s ))
if (( ma_now >= 30 )); then
    warn "mediaanalysisd is using ${ma_now}% CPU right now. After a major upgrade it builds the Spotlight/Siri semantic index for 1-3 days." \
         "Leave the Mac on power overnight. Exclude build folders in System Settings > Spotlight > Search Privacy."
elif (( ma > 1800 && ma_pct >= 10 )); then
    info "mediaanalysisd used $(( ma / 60 )) min since boot (${ma_pct}% of a core on average) and is quiet right now."
    info "It works in bursts while the Mac is idle and on power, so the post-upgrade index may not be finished yet."
fi
spot="$(mdutil -s /System/Volumes/Data 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')"
case "$spot" in
    *enabled*)  ok "Spotlight indexing enabled on the Data volume (expected; macOS 27 features depend on it)" ;;
    *disabled*) warn "Spotlight indexing is OFF. Siri AI, Mail/Xcode search and 'mas' need it." "sudo mdutil -i on /System/Volumes/Data (starts a full reindex)" ;;
    *)          info "Spotlight: ${spot:-unknown}" ;;
esac

# --- Display and animations ----------------------------------------------------------------------------
print_step "Display and animations"
displays="$(system_profiler SPDisplaysDataType 2>/dev/null)"
printf '%s\n' "$displays" | awk '
    /^        [^ ].*:$/ { name=$0; sub(/^ +/, "", name); sub(/:$/, "", name) }
    /UI Looks like:/    { sub(/^ +UI Looks like: /, ""); printf "  %-22s %s\n", name, $0 }'
# The built-in ProMotion panel is always variable-refresh; only external displays matter here.
if printf '%s\n' "$displays" | awk '/^        [^ ].*:$/{n++; ext[n]=1} /Connection Type: Internal/{ext[n]=0} END{for(i=1;i<=n;i++) if(ext[i]) f=1; exit !f}'; then
    info "External display connected. If it feels laggy and Displays > Refresh Rate shows 'Variable',"
    info "pick a fixed rate. '--deep' counts the display timing errors WindowServer logs."
fi
if [[ "$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 0)" == 1 ]]; then ok "Reduce transparency on"
else info "Reduce transparency off (Liquid Glass fully on)"; fi
if [[ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || echo 0)" == 1 ]]; then ok "Reduce motion on"
else info "Reduce motion off. If animations feel slow: System Settings > Accessibility > Motion > Reduce motion"; fi
if [[ $DEEP == 1 ]]; then
    info "Scanning the last hour of WindowServer logs (this can take a minute)..."
    n="$(log show --last 1h --style compact --predicate 'process == "WindowServer" AND eventMessage CONTAINS "actual_host_time"' 2>/dev/null | grep -c actual_host_time || true)"
    if (( ${n:-0} > 1000 )); then
        warn "$n display timing errors from WindowServer in the last hour (often an external monitor on variable refresh)." \
             "Set a fixed refresh rate for the external display, use the Mac for a while, then run --deep again."
    else
        ok "Display timing errors in the last hour: ${n:-0}"
    fi
fi

# --- Siri / Apple Intelligence -------------------------------------------------------------------------
print_step "Siri and Apple Intelligence"
if launchctl print "gui/$uid/com.apple.campo" 2>/dev/null | grep -q 'state = running'; then
    info "Siri AI agent (com.apple.campo) is running; the classic Siri keys do not stop it."
    info "If you do not use it: System Settings > Siri > Turn Off Siri, or use Siri Classic."
fi
if [[ "$(defaults read com.apple.assistant.support 'Assistant Enabled' 2>/dev/null || echo 1)" == 0 ]]; then info "Classic Siri: off"
else info "Classic Siri: on"; fi
disabled="$(launchctl print-disabled "gui/$uid" 2>/dev/null || true)"
legacy=""
for label in com.apple.parsecd com.apple.knowledge-agent com.apple.assistantd; do
    printf '%s\n' "$disabled" | grep -q "\"$label\" => disabled" && legacy="$legacy $label"
done
[[ -n "$legacy" ]] && warn "Apple agents disabled by the 2025 macos-tweaks.sh:$legacy" "launchctl enable gui/$uid/<label> (or ./restore-defaults.sh), then log out and in"

# --- Updates, analytics, management --------------------------------------------------------------------
print_step "Updates and analytics (effective, system-wide values)"
info "$(softwareupdate --schedule 2>/dev/null | head -1)"
su_plist=/Library/Preferences/com.apple.SoftwareUpdate
for k in AutomaticDownload AutomaticallyInstallMacOSUpdates CriticalUpdateInstall; do
    info "$k = $(defaults read "$su_plist" "$k" 2>/dev/null || echo 'not set (default)')"
done
if defaults read "$su_plist" 2>/dev/null | grep -q DDM || [[ -d /Library/Intune ]]; then
    info "Software updates on this Mac are managed by MDM: the policy comes from your IT department."
fi
diag="/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist"
if [[ "$(defaults read "$diag" AutoSubmit 2>/dev/null || echo 1)" == 0 ]]; then ok "Share Mac Analytics: off"
else info "Share Mac Analytics: on (System Settings > Privacy & Security > Analytics & Improvements)"; fi

# --- Power and battery ----------------------------------------------------------------------------------------
print_step "Power and battery"
if pmset -g custom 2>/dev/null | awk '$1=="tcpkeepalive" && $2==0 {f=1} END{exit !f}'; then
    warn "TCP keep-alive during sleep is off (set by the 2025 macos-tweaks.sh): Find My Mac and MDM push do not work while asleep." \
         "sudo pmset -a tcpkeepalive 1   (or run ./macos-tweaks.sh, which now restores it)"
fi
if pmset -g batt 2>/dev/null | grep -q InternalBattery; then
    # Only a user-set limit counts; Optimized Charging also reports temporary limits.
    limit="$(pmset -g battlimit 2>/dev/null | awk -F'= ' '
        /\{/ { r=""; s="" }
        /chargeSocLimitReason/ { r=$2 }
        /chargeSocLimitSoc/ { s=$2; gsub(/;/, "", s) }
        /\}/ { if (r ~ /^manualChargeLimit/ && s != "") { print s; exit } }')"
    if [[ -n "$limit" && "$limit" != 100 ]]; then ok "Native charge limit: ${limit}%"
    else info "No charge limit set (System Settings > Battery > Charging (i) > Charge Limit, macOS 26.4+)"; fi
    if [[ -d /Applications/AlDente.app && -n "$limit" && "$limit" != 100 ]]; then
        warn "AlDente and the native charge limit are both active; they can fight each other." "Use one: set the native limit to 100% or remove AlDente."
    fi
    system_profiler SPPowerDataType 2>/dev/null | awk -F': ' '/Cycle Count|Condition|Maximum Capacity/{gsub(/^ +/,"",$1); printf "  %s: %s\n", $1, $2}'
fi

# --- Login and background items ----------------------------------------------------------------------------
print_step "Third-party launch agents and daemons"
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
    items=""
    for f in "$d"/*.plist; do
        [[ -e "$f" ]] || continue
        f="$(basename "$f" .plist)"
        [[ "$f" == com.apple.* ]] || items="$items $f"
    done
    [[ -n "$items" ]] && info "$d:$items"
done
info "Turn off what you do not need: System Settings > General > Login Items & Extensions."

# --- Homebrew ---------------------------------------------------------------------------------------------------
print_step "Homebrew"
if brew_bin="$(command -v brew)"; then
    info "$("$brew_bin" --version 2>/dev/null | head -1)"
    # Run brew with the caller's PATH (this script puts /usr/bin first). Keep the
    # indented detail lines (e.g. tap names). The GNU-first PATH warnings are by
    # design of this repo's shell config, so they are dropped unless opted out.
    doc="$(PATH="$ORIG_PATH" "$brew_bin" doctor 2>&1 | awk '/^(Warning|Error):/{p=1; print; next} p && /^  [^ ]/{print; next} {p=0}')"
    if [[ "${MAC_DEV_GNU_FIRST:-1}" == 1 ]]; then
        doc="$(printf '%s\n' "$doc" | awk '/^Warning: Putting non-prefixed/{skip=1; next} /^(Warning|Error):/{skip=0} !skip')"
    fi
    if [[ -n "$doc" ]]; then
        warn "brew doctor reports:" "Read 'brew doctor' in full; untrusted taps need 'brew trust --tap <name>'"
        printf '%s\n' "$doc" | sed 's/^/    /'
    else
        ok "brew doctor: no warnings"
    fi
    outdated="$("$brew_bin" outdated --quiet 2>/dev/null | tr '\n' ' ')"
    [[ -n "$outdated" ]] && info "Outdated: $outdated"
    if "$brew_bin" bundle check --no-upgrade --file="$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
        ok "Everything in the Brewfile is installed"
    else
        warn "Brewfile packages are missing:" "brew bundle install --no-upgrade --file=\"$SCRIPT_DIR/Brewfile\""
        "$brew_bin" bundle check --no-upgrade --file="$SCRIPT_DIR/Brewfile" --verbose 2>&1 | grep '→' | sed 's/^/    /'
    fi
else
    warn "Homebrew is not installed" "./setup-mac.sh"
fi

# --- Xcode ------------------------------------------------------------------------------------------------------------
print_step "Xcode and Command Line Tools"
active="$(xcode-select -p 2>/dev/null || echo none)"
xc_app=""
case "$active" in *.app/Contents/Developer) xc_app="${active%/Contents/Developer}" ;; esac
if [[ -z "$xc_app" ]]; then
    for p in /Applications/Xcode*.app "$HOME"/Applications/Xcode*.app; do [[ -d "$p" ]] && { xc_app="$p"; break; }; done
fi
xc=""; [[ -n "$xc_app" ]] && xc="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$xc_app/Contents/Info.plist" 2>/dev/null)"
clt="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/^version:/{print $2}')"
info "Xcode ${xc:-not installed}${xc_app:+ ($xc_app)}, CLT ${clt:-not installed}, active: $active"
if [[ -n "$xc" && -n "$clt" && "${xc%%.*}" != "${clt%%.*}" ]]; then
    warn "Xcode and the Command Line Tools are different major versions." "softwareupdate --list, then install the matching Command Line Tools"
fi
if [[ -n "$xc_app" ]]; then
    if [[ "$active" != "$xc_app"/* ]]; then
        warn "Xcode is installed but the active developer directory is $active, so xcodebuild and KMP iOS builds fail." "sudo xcode-select -s \"$xc_app/Contents/Developer\""
    elif ! xcodebuild -license check >/dev/null 2>&1 || ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        warn "Xcode $xc still needs its licence agreement or first-launch components." "sudo xcodebuild -runFirstLaunch"
    else
        sdk="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null)"
        rts="$(xcrun simctl list runtimes 2>/dev/null | awk '/^iOS / && !/unavailable/{printf "%s ", $2}')"
        if [[ -z "$rts" ]]; then
            warn "No iOS simulator runtime is installed." "xcodebuild -downloadPlatform iOS   (or Xcode > Settings > Components)"
        elif [[ -n "$sdk" && " $rts" != *" ${sdk%%.*}."* ]]; then
            info "iOS simulator runtimes: ${rts}(none for the iOS ${sdk%%.*} SDK; builds still run on these."
            info "Optional: xcodebuild -downloadPlatform iOS, then xcrun simctl runtime delete the old one)"
        fi
    fi
fi

# --- Android, Java, Android CLI ------------------------------------------------------------------------------------------------
print_step "Android and Java"
AH="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -d "$AH" ]]; then
    ok "ANDROID_HOME: $AH"
    for sub in platform-tools emulator cmdline-tools/latest/bin; do
        [[ -d "$AH/$sub" ]] || warn "Missing $AH/$sub" "android sdk install ${sub%/bin}"
    done
else
    warn "No Android SDK at $AH" "Install Android Studio with JetBrains Toolbox, or: android sdk install platform-tools"
fi
[[ -n "${ANDROID_SDK_ROOT:-}" ]] && warn "ANDROID_SDK_ROOT is set; it is deprecated." "Remove it and keep only ANDROID_HOME"
android_bins="$(IFS=:; for d in $ORIG_PATH; do [[ -x "$d/android" ]] && echo "$d/android"; done | awk '!seen[$0]++')"
if [[ -n "$android_bins" ]]; then
    first="$(printf '%s\n' "$android_bins" | head -1)"
    ok "Android CLI $("$first" info version 2>/dev/null | tail -1) ($first)"
    n="$(printf '%s\n' "$android_bins" | wc -l | tr -d ' ')"
    (( n > 1 )) && info "$n android launchers on PATH; they share ~/.android, so 'android update' updates all: $(printf '%s' "$android_bins" | tr '\n' ' ')"
    info "Update with: android update"
else
    warn "Android CLI ('android') is not on PATH" "brew install --cask android-cli"
fi
if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    jver="$(sed -nE 's/^JAVA_VERSION="([^"]+)".*/\1/p' "$JAVA_HOME/release" 2>/dev/null)"
    [[ -n "$jver" ]] || jver="$("$JAVA_HOME/bin/java" -version 2>&1 | sed -nE 's/.*version "([^"]+)".*/\1/p' | head -1)"
    ok "JAVA_HOME: JDK ${jver:-unknown} ($JAVA_HOME)"
    jmaj="${jver%%.*}"
    if [[ "$jmaj" =~ ^[0-9]+$ ]] && (( jmaj >= 25 )); then
        info "Gradle runs on JDK $jmaj only from Gradle 9.1: ./gradlew in projects with an older wrapper fails in the terminal."
        info "Per project: upgrade the wrapper, or pin a JDK 21 toolchain in gradle/gradle-daemon-jvm.properties."
    fi
elif [[ -n "${JAVA_HOME:-}" ]]; then
    warn "JAVA_HOME points to a missing JDK: $JAVA_HOME" "Remove it from ~/.zshrc; the managed shell config finds Android Studio's JBR"
else
    warn "JAVA_HOME is not set" "Install Android Studio via JetBrains Toolbox, then open a new shell"
fi
studio=""
for p in "$HOME/Applications/Android Studio.app" "/Applications/Android Studio.app"; do [[ -d "$p" ]] && { studio="$p"; break; }; done
[[ -n "$studio" ]] && info "Android Studio $(defaults read "$studio/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null) at $studio"

# --- Shell ---------------------------------------------------------------------------------------------------------------------------------
print_step "Shell environment"
dead=""; dead_sys=""; dups=""; seen=":"
IFS=: read -r -a entries <<< "$ORIG_PATH"
for e in ${entries[@]+"${entries[@]}"}; do
    [[ -z "$e" ]] && continue
    case "$e" in /var/run/com.apple.security.cryptexd/*) continue ;; esac   # added by macOS itself
    if [[ ! -d "$e" ]]; then
        src="$(grep -lxF -- "$e" /etc/paths /etc/paths.d/* 2>/dev/null | head -1)"
        if [[ -n "$src" ]]; then
            case " $dead_sys " in *" $e ($src) "*) ;; *) dead_sys="$dead_sys $e ($src)" ;; esac
        else
            case " $dead " in *" $e "*) ;; *) dead="$dead $e" ;; esac
        fi
    fi
    case "$seen" in
        *":$e:"*) case " $dups " in *" $e "*) ;; *) dups="$dups $e" ;; esac ;;
        *) seen="$seen$e:" ;;
    esac
done
[[ -n "$dead" ]] && warn "PATH entries that do not exist:$dead" "Remove them from ~/.zshrc / ~/.zprofile"
[[ -n "$dead_sys" ]] && info "Dead PATH entries from system files (need sudo to edit):$dead_sys"
[[ -n "$dups" ]] && info "Duplicate PATH entries:$dups"
managed="$HOME/.config/mac-android-dev-setup/zshrc.zsh"
if [[ -f "$managed" ]]; then
    if cmp -s "$managed" "$SCRIPT_DIR/zsh/mac-android-dev.zsh"; then ok "Managed shell config is current"
    else warn "Managed shell config differs from the repo version" "./setup-mac.sh --shell"; fi
    grep -q 'mac-android-dev-setup/zshrc.zsh' "$HOME/.zshrc" 2>/dev/null || warn "~/.zshrc does not source the managed config" "./setup-mac.sh --shell"
else
    info "Managed shell config not installed (./setup-mac.sh --shell)"
fi
# Only line numbers are printed: ~/.zshrc can hold secrets.
legacy_lines="$(grep -nE "$LEGACY_ZSHRC_RE" "$HOME/.zshrc" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
if [[ -n "$legacy_lines" ]]; then
    warn "~/.zshrc still has lines from the 2025 generated config (dead \$ANDROID_HOME/tools, eza bare --icons, grep=rg / find=fd, GNU PATH) at lines: $legacy_lines" \
         "Delete them; the managed config replaces them (README > Upgrading from the 2025 version)"
fi

# --- Rosetta and Intel apps --------------------------------------------------------------------------------------------------------------
print_step "Rosetta"
intel=""
for app in /Applications/*.app "$HOME"/Applications/*.app; do
    [[ -d "$app" ]] || continue
    exe="$(defaults read "$app/Contents/Info.plist" CFBundleExecutable 2>/dev/null)" || continue
    bin="$app/Contents/MacOS/$exe"
    [[ -f "$bin" ]] || continue
    archs="$(lipo -archs "$bin" 2>/dev/null || true)"
    [[ -n "$archs" && "$archs" != *arm64* ]] && intel="$intel $(basename "$app" .app),"
done
if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    if [[ -n "$intel" ]]; then info "Rosetta is installed. Intel-only apps (they stop working when macOS 28 drops Intel support):${intel%,}"
    else info "Rosetta is installed but no Intel-only apps were found."; fi
elif [[ -n "$intel" ]]; then
    warn "Rosetta is not installed (the macOS 27 upgrade does not restore it); these Intel-only apps will not open:${intel%,}" \
         "softwareupdate --install-rosetta --agree-to-license, or replace the apps"
else
    ok "No Intel-only apps; Rosetta not needed"
fi

# --- Summary -----------------------------------------------------------------------------------------------------------------------------------
echo
if (( WARNINGS == 0 )); then
    print_success "No problems found."
else
    printf '%s%d item(s) need attention; each warning above lists its fix.%s\n' "$C_YELLOW" "$WARNINGS" "$C_NC"
fi

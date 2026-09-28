# shellcheck shell=bash
# Shared helpers for the mac-android-dev-setup scripts.
# Sourced, never executed. Must stay compatible with macOS /bin/bash 3.2:
# no associative arrays, no mapfile, no ${var,,}, no empty "${arr[@]}" under set -u.

# Remember the caller's PATH (post-update-check.sh audits it and runs brew with
# it), then put the system tools first so GNU coreutils on the user's PATH
# cannot change the behaviour of sed/date/stat/cut/find inside these scripts.
# shellcheck disable=SC2034  # used by the scripts that source this file
ORIG_PATH="${PATH:-}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:${PATH:-}"

if [[ -t 1 ]]; then
    C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[0;34m'; C_DIM=$'\033[2m'; C_NC=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''; C_NC=''
fi

WARNINGS=0   # counted by print_warning (post-update-check.sh summary)
FAILURES=0   # counted by try (setup-mac.sh exit status)
print_step()    { printf '%s==>%s %s\n' "$C_BLUE" "$C_NC" "$1"; }
print_success() { printf '%s✓%s %s\n' "$C_GREEN" "$C_NC" "$1"; }
print_info()    { printf '  %s%s%s\n' "$C_DIM" "$1" "$C_NC"; }
print_warning() { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_NC" "$1"; WARNINGS=$((WARNINGS + 1)); }
print_error()   { printf '%s✗%s %s\n' "$C_RED" "$C_NC" "$1" >&2; }
die()           { print_error "$1"; exit 1; }

# DRY_RUN=1 (or -n/--dry-run) prints every state-changing command instead of
# running it. Any value other than 0/empty counts as a dry run: the safety
# flag must fail closed (DRY_RUN=true must not mean "do it for real").
DRY_RUN="${DRY_RUN:-0}"
case "$DRY_RUN" in
    0|'') DRY_RUN=0 ;;
    1)    ;;
    *)    printf '%s⚠%s DRY_RUN=%s is not 0 or 1; treating it as a dry run.\n' "$C_YELLOW" "$C_NC" "$DRY_RUN" >&2
          DRY_RUN=1 ;;
esac
export DRY_RUN
is_dry_run() { [[ "$DRY_RUN" == 1 ]]; }
enable_dry_run() { DRY_RUN=1; export DRY_RUN; }

# run CMD...: execute, or print it (shell-quoted) in dry-run. Returns the status.
# A single argument is printed as-is, for descriptive pseudo-commands.
run() {
    if is_dry_run; then
        printf '  %s[dry-run]%s' "$C_DIM" "$C_NC"
        if (( $# == 1 )); then printf ' %s' "$1"; else printf ' %q' "$@"; fi
        printf '\n'
        return 0
    fi
    "$@"
}

# try CMD...: like run, but a failure is reported, counted, and does not stop the script.
try() {
    if run "$@"; then return 0; fi
    FAILURES=$((FAILURES + 1))
    print_warning "Failed (continuing): $*"
    return 1
}

# confirm "Question?": y/N prompt. Without a terminal (CI, pipes) the answer is No.
confirm() {
    local reply=''
    if [[ "${ASSUME_YES:-0}" == 1 ]]; then return 0; fi
    [[ -t 0 ]] || return 1
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

macos_version() { sw_vers -productVersion; }
macos_major()   { sw_vers -productVersion | cut -d. -f1; }

# Newest macOS these scripts were checked against.
TESTED_MACOS_MAJOR=27

require_apple_silicon() {
    [[ "$(uname -m)" == "arm64" ]] || die "Apple silicon required: macOS 27, Xcode 27 and Homebrew 7 no longer support Intel Macs."
}

# require_macos MIN_MAJOR: hard floor; warn above the tested version.
require_macos() {
    local major
    [[ "$(uname -s)" == "Darwin" ]] || die "This script only runs on macOS."
    major="$(macos_major)"
    (( major >= $1 )) || die "macOS $1 or later required (found $(macos_version))."
    if (( major > TESTED_MACOS_MAJOR )); then
        print_warning "macOS $(macos_version) is newer than the last tested release ($TESTED_MACOS_MAJOR). Preview with --dry-run first."
    fi
}

# ensure_sudo: ask for the admin password once. Returns 1 (caller skips the
# step) instead of aborting the whole script when it is refused.
ensure_sudo() {
    is_dry_run && return 0
    sudo -v && return 0
    print_warning "Administrator rights not granted; skipping this step."
    return 1
}

# --- Backups ------------------------------------------------------------------------
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.mac-android-dev-setup/backups}"

# new_backup_dir LABEL: create and print a timestamped backup directory.
new_backup_dir() {
    local dir
    dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-$1"
    if ! is_dry_run; then mkdir -p "$dir"; fi
    printf '%s\n' "$dir"
}

# backup_domains DIR DOMAIN...: `defaults export` whole domains into DIR
# (used for the Dock before --reset-dock; restore with `defaults import`).
backup_domains() {
    local dir="$1" d
    shift
    is_dry_run && { print_info "[dry-run] would back up: $*"; return 0; }
    for d in "$@"; do
        defaults export "$d" "$dir/$d.plist" 2>/dev/null || print_info "could not back up $d (missing or protected)"
    done
}

# set_pref SCOPE DOMAIN KEY TYPE VALUE
#   SCOPE user|host (host = -currentHost), TYPE bool|int|float|string.
# Records the key's previous type and value in $KEYS_FILE (tab-separated, "-"
# when the key did not exist) so restore-defaults.sh --from-backup can put back
# exactly these keys and nothing else. Returns the status of the write.
set_pref() {
    local scope="$1" domain="$2" key="$3" type="$4" value="$5" host="" t v
    [[ "$scope" == host ]] && host="-currentHost"
    if ! is_dry_run && [[ -n "${KEYS_FILE:-}" ]]; then
        if t="$(defaults ${host:+"$host"} read-type "$domain" "$key" 2>/dev/null)"; then
            t="${t#Type is }"
            case "$t" in
                boolean|integer|float|string) v="$(defaults ${host:+"$host"} read "$domain" "$key" 2>/dev/null)" ;;
                *) v="-" ;;   # arrays/dicts are not restored key-wise
            esac
        else
            t="-"; v="-"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$scope" "$domain" "$key" "$t" "$v" >> "$KEYS_FILE"
    fi
    run defaults ${host:+"$host"} write "$domain" "$key" "-$type" "$value" 2>/dev/null
}

# tweak ...: set_pref, reporting (not aborting on) a failed write.
tweak() {
    set_pref "$@" && return 0
    FAILURES=$((FAILURES + 1))
    print_warning "Could not write $2 $3"
    return 1
}

# Lines the 2025 setup-mac.sh wrote into ~/.zshrc. Shared by setup-mac.sh and
# post-update-check.sh; they only ever print line numbers (~/.zshrc can hold secrets).
LEGACY_ZSHRC_RE='ANDROID_HOME/tools[:"]|--icons'"'"'|--icons( |$)|alias grep=['"'"'"]?rg([ '"'"'"]|$)|alias find=['"'"'"]?fd([ '"'"'"]|$)|/opt/[a-z-]+/libexec/gnubin'

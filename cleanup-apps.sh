#!/bin/bash
#
# Remove the optional Apple apps that CAN be removed, and report where disk
# space goes on a mobile-dev Mac. Nothing is deleted without a prompt.
#
#   ./cleanup-apps.sh                       offer to trash GarageBand/iMovie/Numbers/Pages, then report
#   ./cleanup-apps.sh --report-only         only print the disk usage report
#   ./cleanup-apps.sh --garageband-content  offer to trash the GarageBand/Logic sound libraries
#   ./cleanup-apps.sh --reset-dock          rebuild the Dock (backs it up first; needs dockutil)
#   ./cleanup-apps.sh --apps                offer app removal too when combined with the options above
#   ./cleanup-apps.sh -n|--dry-run ...      print what would happen (same as DRY_RUN=1)
#
# Built-in apps (Mail, Photos, Music, TV, News, Maps, ...) live on the signed,
# read-only system volume (/System/Applications) since macOS 11 and cannot be
# deleted. The 2025 version of this script tried anyway (a no-op) and used
# substring globs such as ~/Library/Caches/*Home* that could delete unrelated data.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; }

DO_APPS=""; DO_GB_CONTENT=0; DO_DOCK=0; REPORT_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --apps)               DO_APPS=1 ;;
        --report-only)        REPORT_ONLY=1 ;;
        --garageband-content) DO_GB_CONTENT=1 ;;
        --reset-dock)         DO_DOCK=1 ;;
        -n|--dry-run)         enable_dry_run ;;
        -h|--help)            usage; exit 0 ;;
        *)                    usage; die "Unknown option: $arg" ;;
    esac
done
# App removal is the default only when no other action was asked for.
if [[ -z "$DO_APPS" ]]; then
    if [[ $REPORT_ONLY == 1 || $DO_GB_CONTENT == 1 || $DO_DOCK == 1 ]]; then DO_APPS=0; else DO_APPS=1; fi
fi
[[ $REPORT_ONLY == 1 ]] && { DO_APPS=0; DO_GB_CONTENT=0; DO_DOCK=0; }

require_apple_silicon
require_macos 15
is_dry_run && print_warning "Dry run: nothing will be changed."

# move_to_trash PATH: reversible removal (root-owned App Store apps need sudo).
move_to_trash() {
    local src="$1" base dest
    base="$(basename "$src")"
    dest="$HOME/.Trash/${base%.*} $(date +%Y%m%d-%H%M%S).${base##*.}"
    [[ "$base" == *.* ]] || dest="$HOME/.Trash/$base $(date +%Y%m%d-%H%M%S)"
    if [[ -w "$(dirname "$src")" && -O "$src" ]]; then
        run mv "$src" "$dest"
    else
        ensure_sudo || return 1
        run sudo mv "$src" "$dest"
    fi
}

# bundle id for the removable App Store apps (bash 3.2: no associative arrays)
bundle_id_for() {
    case "$1" in
        GarageBand) echo com.apple.garageband10 ;;
        iMovie)     echo com.apple.iMovieApp ;;
        Numbers)    echo com.apple.iWork.Numbers ;;
        Pages)      echo com.apple.iWork.Pages ;;
        *)          return 1 ;;
    esac
}

# --- Removable Apple apps ----------------------------------------------------------------
# Only apps delivered through the App Store live in /Applications. They can be
# re-downloaded from the App Store at any time. Keynote is intentionally kept.
if [[ $DO_APPS == 1 ]]; then
    print_step "Optional Apple apps in /Applications"
    found=0
    for name in GarageBand iMovie Numbers Pages; do
        app="/Applications/$name.app"
        [[ -d "$app" ]] || continue
        found=1
        size="$(du -sh "$app" 2>/dev/null | cut -f1)"
        if is_dry_run || confirm "Move $name ($size) to the Trash?"; then
            if move_to_trash "$app"; then
                print_success "$name moved to the Trash (drag it back to /Applications to restore; Finder's Put Back does not apply), or re-download it from the App Store"
                id="$(bundle_id_for "$name")"
                # Caches and saved window state are safe to drop. The container
                # (~/Library/Containers/$id) can hold your documents, so it is
                # only reported, never deleted.
                for p in "$HOME/Library/Caches/$id" "$HOME/Library/Saved Application State/$id.savedState"; do
                    [[ -e "$p" ]] && try rm -rf "$p"
                done
                [[ -d "$HOME/Library/Containers/$id" ]] && \
                    print_info "Kept $HOME/Library/Containers/$id (may contain documents; delete it yourself if unneeded)"
            else
                print_warning "Could not move $name to the Trash"
            fi
        else
            print_info "Kept $name"
        fi
    done
    [[ $found == 0 ]] && print_success "None of GarageBand, iMovie, Numbers, Pages are installed"
fi

# --- GarageBand / Logic sound libraries (opt-in) ----------------------------------------------
if [[ $DO_GB_CONTENT == 1 ]]; then
    print_step "GarageBand / Logic sound libraries"
    if [[ -d /Applications/GarageBand.app || -d "/Applications/Logic Pro.app" ]]; then
        print_info "GarageBand or Logic Pro is installed; keeping their sound libraries."
    else
        for p in "/Library/Application Support/GarageBand" "/Library/Application Support/Logic" "/Library/Audio/Apple Loops"; do
            [[ -d "$p" ]] || continue
            size="$(du -sh "$p" 2>/dev/null | cut -f1)"
            print_info "Other audio apps can use Apple Loops; only remove them if nothing else needs them."
            if is_dry_run || confirm "Move $p ($size) to the Trash?"; then
                move_to_trash "$p" && print_success "Moved $p to the Trash"
            fi
        done
    fi
fi

# --- Dock (opt-in) --------------------------------------------------------------------------------
if [[ $DO_DOCK == 1 ]]; then
    print_step "Rebuilding the Dock"
    if ! command -v dockutil >/dev/null 2>&1; then
        print_warning "dockutil is not installed (brew install dockutil); Dock left unchanged."
    elif is_dry_run || confirm "Replace ALL current Dock items with the dev set (a backup is made first)?"; then
        BACKUP_DIR="$(new_backup_dir dock)"
        backup_domains "$BACKUP_DIR" com.apple.dock
        studio=""
        for p in "$HOME/Applications/Android Studio.app" "/Applications/Android Studio.app"; do
            [[ -d "$p" ]] && { studio="$p"; break; }
        done
        run dockutil --remove all --no-restart
        for app in "/Applications/Ghostty.app" "$studio" "/Applications/Visual Studio Code.app" \
                   "/Applications/Google Chrome.app" "/System/Applications/System Settings.app"; do
            [[ -n "$app" && -d "$app" ]] && run dockutil --add "$app" --no-restart
        done
        if is_dry_run; then run killall Dock; else killall Dock >/dev/null 2>&1 || true; fi
        print_success "Dock rebuilt. Undo: defaults import com.apple.dock \"$BACKUP_DIR/com.apple.dock.plist\" && killall Dock"
    fi
fi

# --- Where the space is (read-only) ----------------------------------------------------------------
print_step "Disk usage of common dev caches (nothing is deleted)"
for p in \
    "$HOME/.gradle/caches" "$HOME/.gradle/wrapper/dists" "$HOME/.android/avd" \
    "$HOME/Library/Android/sdk/system-images" "$HOME/Library/Developer/CoreSimulator" \
    "$HOME/Library/Developer/Xcode/DerivedData" "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
    "$HOME/Library/Caches/Homebrew" "$HOME/Library/Caches/JetBrains" "$HOME/.m2/repository" \
    "$HOME/.npm" "$HOME/.konan"; do
    [[ -d "$p" ]] && printf '  %8s  %s\n' "$(du -sh "$p" 2>/dev/null | cut -f1)" "$p"
done
cat <<'EOF'

  Safe ways to reclaim space:
    brew cleanup --prune=all            old Homebrew downloads and versions
    xcrun simctl delete unavailable     simulators for runtimes you no longer have
    rm -rf ~/Library/Developer/Xcode/DerivedData    (rebuilt on next build)
    ./gradlew --stop                    stops idle Gradle daemons (frees RAM)
    JetBrains Toolbox > Settings        remove old IDE versions and their caches
    android emulator list / remove      delete emulators you do not use
EOF
print_success "Done."

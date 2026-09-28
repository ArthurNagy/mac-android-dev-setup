# mac-android-dev-setup: managed shell configuration (zsh).
#
# setup-mac.sh copies this file to ~/.config/mac-android-dev-setup/zshrc.zsh
# and sources it from a marked block at the end of ~/.zshrc. Re-run
# `setup-mac.sh --shell` to update it; keep personal settings and secrets in ~/.zshrc.
#
# Options (set in ~/.zshrc *before* the managed block):
#   MAC_DEV_GNU_FIRST=0     keep BSD/macOS userland ahead of GNU tools
#   MAC_DEV_MODERN_LS=0     do not define the eza shortcuts l/la/ll/lt/lst/llt
#   MAC_DEV_ALIAS_CORE=1    also alias ls -> eza and cat -> bat (off by default, see below)

typeset -U path PATH   # keep PATH entries unique

# --- Homebrew (Apple silicon) ------------------------------------------------
if [[ -z "${HOMEBREW_PREFIX:-}" && -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
_mad_brew="${HOMEBREW_PREFIX:-/opt/homebrew}"

# --- GNU userland first (Linux-like CLI) --------------------------------------
# `brew doctor` warns about this because building formulae from source can
# break; bottles are unaffected. The repo's scripts pin /usr/bin first anyway.
if [[ "${MAC_DEV_GNU_FIRST:-1}" == 1 ]]; then
    for _mad_gnu in coreutils findutils gnu-tar gnu-sed gawk grep; do
        [[ -d "$_mad_brew/opt/$_mad_gnu/libexec/gnubin" ]] && path=("$_mad_brew/opt/$_mad_gnu/libexec/gnubin" $path)
    done
    # gnu-getopt is keg-only and has no gnubin; its bin/ holds just `getopt`.
    [[ -d "$_mad_brew/opt/gnu-getopt/bin" ]] && path=("$_mad_brew/opt/gnu-getopt/bin" $path)
    unset _mad_gnu
fi

# --- Editor -------------------------------------------------------------------
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"

# --- Android SDK + Android CLI --------------------------------------------------
# ANDROID_SDK_ROOT is deprecated; ANDROID_HOME is the only variable to set.
# $ANDROID_HOME/tools no longer exists (replaced by cmdline-tools).
# Appended, not prepended: platform-tools ships its own sqlite3, which must not
# shadow macOS's. The Android CLI (`android`, cask android-cli) also ships in
# cmdline-tools/latest/bin; every launcher shares ~/.android, so `android update`
# upgrades all of them.
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
for _mad_dir in "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" "$ANDROID_HOME/cmdline-tools/latest/bin"; do
    [[ -d "$_mad_dir" ]] && path+=("$_mad_dir")
done
unset _mad_dir

# --- Java ---------------------------------------------------------------------
# Keep a valid JAVA_HOME from ~/.zshrc; otherwise use Android Studio's bundled
# JBR (JetBrains Toolbox installs into ~/Applications), then any system JDK.
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-/nonexistent}/bin/java" ]]; then
    unset JAVA_HOME
    for _mad_jbr in \
        "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
        "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
        if [[ -x "$_mad_jbr/bin/java" ]]; then export JAVA_HOME="$_mad_jbr"; break; fi
    done
    unset _mad_jbr
    if [[ -z "${JAVA_HOME:-}" ]] && /usr/libexec/java_home >/dev/null 2>&1; then
        export JAVA_HOME="$(/usr/libexec/java_home)"
    fi
fi

# --- Aliases from the 2025 version of this repo ---------------------------------
# That version wrote these into ~/.zshrc. Remove exactly those values (your own
# aliases with other values are kept): they shadow standard commands whose
# flags differ, which breaks pasted commands and AI agents that inherit aliases.
#   ls='eza --icons'  `ls DIR` fails (bare --icons takes the next argument), `ls -ltr` fails
#   cat='bat'         `cat -v/-e/-t` fail
#   grep='rg'         `grep -r x .` means --replace to ripgrep
#   find='fd'         `find . -name x` fails
#   install/info      shadow /usr/bin/install and GNU info
#   mount/netstat     `mount DEV DIR` breaks; BSD netstat has no -tulpn
[[ ${aliases[ls]-} == 'eza --icons' ]] && unalias ls
[[ ${aliases[cat]-} == 'bat' ]] && unalias cat
[[ ${aliases[grep]-} == 'rg' ]] && unalias grep
[[ ${aliases[find]-} == 'fd' ]] && unalias find
[[ ${aliases[install]-} == 'brew install' ]] && unalias install
[[ ${aliases[info]-} == 'brew info' ]] && unalias info
[[ ${aliases[mount]-} == 'mount | column -t' ]] && unalias mount
[[ ${aliases[netstat]-} == 'netstat -tulpn' ]] && unalias netstat

# --- Modern replacements, by their own names --------------------------------------
# Use eza, bat, rg and fd by name. `--icons` must be written `--icons=auto`.
if [[ "${MAC_DEV_MODERN_LS:-1}" == 1 ]] && (( $+commands[eza] )); then
    alias l='eza --icons=auto'
    alias la='eza -a --icons=auto'
    alias ll='eza -la --icons=auto --git'
    alias lt='eza -la --icons=auto --sort=modified'
    alias lst='eza --tree --icons=auto'
    alias llt='eza -la --tree --icons=auto --git'
fi
if [[ "${MAC_DEV_ALIAS_CORE:-0}" == 1 ]]; then
    (( $+commands[eza] )) && alias ls='eza --icons=auto'
    (( $+commands[bat] )) && alias cat='bat'
fi
alias vim='nvim'
alias vi='nvim'

# --- Git ----------------------------------------------------------------------
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# --- System information (Linux-style) ---------------------------------------------
alias lscpu='sysctl -n machdep.cpu.brand_string'
alias lsusb='system_profiler SPUSBDataType'
alias lspci='system_profiler SPPCIDataType'
alias mounts='command mount | column -t'
alias sysinfo='fastfetch; df -h; vm_stat'

# --- Network ------------------------------------------------------------------
alias ports='lsof -nP -iTCP -sTCP:LISTEN'
alias listening='lsof -nP -iTCP -sTCP:LISTEN'
alias myip='curl -s https://httpbin.org/ip | jq -r .origin'
alias localip='ipconfig getifaddr en0 || ipconfig getifaddr en1'
alias ips='ifconfig | command grep "inet " | command grep -v 127.0.0.1 | cut -d " " -f2'
alias flush='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'

# --- Processes ------------------------------------------------------------------
alias psg='ps aux | command grep'
alias topcpu='ps aux | sort -k3 -nr | head -10'
alias topmem='ps aux | sort -k4 -nr | head -10'

# --- Packages (brew) ---------------------------------------------------------------
alias remove='brew uninstall'
alias search='brew search'
alias update='brew update && brew upgrade'
alias upgrade='brew upgrade'
alias list='brew list'
alias reload='source ~/.zshrc'
alias brewup='brew update && brew upgrade && brew cleanup'

# --- Maintenance -----------------------------------------------------------------
# macOS updates are not installed from here: on Apple silicon they need
# volume-owner authentication, and managed Macs schedule them via MDM.
alias sysupdate='softwareupdate --list; brew update && brew upgrade && brew cleanup; mas upgrade; (( $+commands[android] )) && android update'
# `periodic` no longer exists on macOS 27, so there is nothing to run for it.
alias sysclean='brew cleanup --prune=all && brew autoremove && xcrun simctl delete unavailable'

# --- launchd (systemd-like) ---------------------------------------------------------
alias services='launchctl list'
alias service-start='launchctl bootstrap'
alias service-stop='launchctl bootout'

# --- Android ------------------------------------------------------------------------
alias adb-devices='adb devices -l'
alias adb-log='adb logcat -v color'
alias adb-install='adb install -r'
alias adb-wireless='adb tcpip 5555'
alias adb-screenshot='adb exec-out screencap -p > screenshot-$(date +%Y%m%d-%H%M%S).png'
alias adb-restart='adb kill-server && adb start-server'
alias emu-list='android emulator list'

# `function` syntax is not subject to alias expansion, so an existing `mkcd`
# alias cannot turn this into a parse error.
unalias mkcd 2>/dev/null
function mkcd { mkdir -p -- "$1" && cd -- "$1"; }

# --- zsh plugins from Homebrew ------------------------------------------------------
# Skipped when Oh My Zsh already loaded them as plugins (avoids double hooks).
if (( ! $+functions[_zsh_autosuggest_start] )) && [[ -r "$_mad_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$_mad_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
# zsh-syntax-highlighting must be sourced last.
if [[ -z "${ZSH_HIGHLIGHT_VERSION:-}" && -r "$_mad_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$_mad_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
unset _mad_brew

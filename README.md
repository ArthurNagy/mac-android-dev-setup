# macOS Mobile Development Setup

Scripts that turn an Apple silicon Mac into a lean Android / Kotlin Multiplatform / iOS development machine with a Linux-like command line. Updated for **macOS 27 (Golden Gate)**, Homebrew 7, Xcode 27 and the new Android CLI.

## What it does

- **Installs the toolchain** from a `Brewfile`: GNU userland, modern CLI tools (eza, bat, ripgrep, fd, fzf, delta), the [Android CLI](https://developer.android.com/tools/agents/android-cli), scrcpy, JetBrains Toolbox (Android Studio), Xcode, OrbStack, Ghostty.
- **Manages your shell config** without overwriting `~/.zshrc`: one marked block sources `~/.config/mac-android-dev-setup/zshrc.zsh` (PATH, `ANDROID_HOME`, `JAVA_HOME`, aliases).
- **Applies macOS tweaks** that still work on macOS 27: Dock, Finder, keyboard repeat, tap to click, text substitutions, reduce transparency and motion. Every key's previous value is recorded first.
- **Checks the machine** after an upgrade: background indexing, display settings, Homebrew, Xcode, Android SDK, Java, PATH and Rosetta. Every warning comes with its fix.
- **Rolls back** to Apple's defaults, or to the recorded previous values.

It does **not** delete built-in apps, turn off Spotlight, disable iCloud daemons or change security settings. System Integrity Protection stays on.

## Quick start

```bash
git clone https://github.com/ArthurNagy/mac-android-dev-setup.git
cd mac-android-dev-setup
./setup-mac.sh --dry-run  # preview
./setup-mac.sh            # tools + shell; asks before tweaks and app cleanup
./post-update-check.sh    # verify
```

Every script that changes something accepts `-n` / `--dry-run` (or `DRY_RUN=1`) and then only prints what it would do.

## Scripts

| Script | Purpose |
|--------|---------|
| `setup-mac.sh` | Command Line Tools, Homebrew, `brew bundle`, Oh My Zsh, managed shell config, Android CLI + SDK baseline. `--all`, `--shell`, `--no-system`. Exits non-zero if a step failed. |
| `macos-tweaks.sh` | Preference tweaks. Asks before the section that turns features off (Handoff, classic Siri, crash dialogs, App Store auto-updates) and before the admin-only power settings. |
| `cleanup-apps.sh` | Moves GarageBand, iMovie, Numbers and Pages to the Trash if you confirm each one, then reports dev-cache disk usage. `--reset-dock`, `--garageband-content`, `--report-only`. |
| `post-update-check.sh` | Read-only health check. `--deep` also scans the last hour of display logs. |
| `restore-defaults.sh` | Deletes every key the tweaks set so macOS uses its own defaults; asks separately before resetting power settings and removing 2025 system-level leftovers. `--from-backup DIR` restores recorded values instead. |

## After a macOS upgrade (for example 26 to 27)

1. **Give it a night.** After a major upgrade, Spotlight rebuilds its index and `mediaanalysisd` builds the new semantic index for Spotlight and Siri AI. This takes one to three days and runs mostly on power while idle. Leave the Mac plugged in overnight. Do not turn Spotlight off: macOS 27 features depend on it, and turning it back on starts the whole rebuild again.
2. **Run `./post-update-check.sh`.** It shows how much CPU the indexers used since boot and right now. It also flags Homebrew drift, Xcode and Command Line Tools problems, missing Rosetta and stale PATH entries.
3. **Update the toolchain:** `brew update && brew upgrade`, `android update`, Android Studio through JetBrains Toolbox, and after an Xcode update optionally `xcodebuild -downloadPlatform iOS` for the matching simulator.
4. **If it still feels slow**, try these reversible settings one at a time:
   - System Settings > Accessibility > Motion > **Reduce motion**. Liquid Glass animations are the largest compositor cost on macOS 26/27.
   - System Settings > Displays > external monitor > **Refresh Rate: a fixed value instead of "Variable"**. Adaptive sync on some monitors floods WindowServer with timing errors; `./post-update-check.sh --deep` counts them.
   - System Settings > Spotlight > **Search Privacy**: add `~/Development` and `~/Library/Android` so builds do not trigger re-indexing. Hidden folders such as `~/.gradle` are never indexed.
   - System Settings > General > **Login Items & Extensions**: turn off background items you do not use.

Running `restore-defaults.sh` does not speed anything up. The tweaks reduce animation work; they do not add any.

## macOS 27 notes

- **Built-in apps cannot be removed.** Mail, Photos, Music and the others live on the signed, read-only system volume. Only App Store apps in `/Applications` can be removed.
- **Siri AI** runs as its own agent (`com.apple.campo`), separate from classic Siri. Turn it off in System Settings > Siri.
- **Software Update** settings live in `/Library/Preferences` and are often MDM-managed. User-level `defaults` keys for them have no effect, so the scripts no longer write them.
- **Battery charge limit** is built in since macOS 26.4: System Settings > Battery > Charging (i) > Charge Limit, from 80 to 100%. AlDente is no longer installed; add it back only for limits below 80%.
- **Rosetta** is not restored by the upgrade to 27, and macOS 28 drops Intel apps. `post-update-check.sh` lists Intel-only apps.
- **Android CLI:** `sdkmanager` is deprecated. Use `android sdk install|list|update`, `android emulator create|start|list`, and `android update` to update the CLI itself. Every copy of the `android` launcher shares `~/.android`, so one `android update` updates them all. `$ANDROID_HOME/tools` no longer exists; the managed config puts `platform-tools`, `emulator` and `cmdline-tools/latest/bin` on PATH.
- **Full Disk Access:** writing the Reduce transparency and Reduce motion preferences needs Full Disk Access for your terminal app. Without it, the tweak script tells you where to switch them on in System Settings.
- **Power:** the 2025 tweaks set `tcpkeepalive 0`, which stops Find My Mac (and MDM push) while asleep. The current tweaks set it back to 1 and use `womp 0` for "no wake for network access"; `post-update-check.sh` warns if it is still 0.

## Shell configuration

`setup-mac.sh` (or `setup-mac.sh --shell`) copies `zsh/mac-android-dev.zsh` to `~/.config/mac-android-dev-setup/zshrc.zsh`, saves `~/.zshrc.backup-<timestamp>`, and appends:

```zsh
# >>> mac-android-dev-setup >>>
# Managed by /path/to/mac-android-dev-setup (re-run setup-mac.sh --shell to update).
[[ -r "$HOME/.config/mac-android-dev-setup/zshrc.zsh" ]] && source "$HOME/.config/mac-android-dev-setup/zshrc.zsh"
# <<< mac-android-dev-setup <<<
```

Keep your own exports and secrets in `~/.zshrc`. Options, set before the block:

- `MAC_DEV_GNU_FIRST=0`: BSD/macOS tools first instead of GNU.
- `MAC_DEV_MODERN_LS=0`: no eza shortcuts.
- `MAC_DEV_ALIAS_CORE=1`: also alias `ls` to eza and `cat` to bat.

`l`, `la`, `ll`, `lt` (by modification time), `lst` and `llt` are eza shortcuts. `ls`, `cat`, `grep` and `find` are **not** aliased by default: `ls -ltr` fails under eza, `cat -v` fails under bat, `grep -r x .` means "replace" to ripgrep and `find . -name` fails under fd. That broke pasted commands and AI coding agents that inherit your aliases. Use `eza`, `bat`, `rg` and `fd` by name.

### Upgrading from the 2025 version

The old `setup-mac.sh` wrote its config straight into `~/.zshrc`. After `./setup-mac.sh --shell`, delete the old lines from `~/.zshrc`: the Homebrew and GNU PATH lines, `ANDROID_HOME`, `JAVA_HOME` and the alias block. `post-update-check.sh` prints the line numbers while they are still there. Until then, the managed config already removes the old `ls`, `cat`, `grep`, `find`, `install`, `info`, `mount` and `netstat` aliases (only when they still have their 2025 values), and re-defines the eza shortcuts with the `--icons` fix.

## Customization

- **Packages:** edit `Brewfile`, then `brew bundle install --no-upgrade`. `brew bundle check --no-upgrade --verbose` lists what is missing. `brew bundle cleanup </dev/null` lists what is installed but not in the file; without the redirect it offers to uninstall all of it, and `y` is a single keypress. Third-party taps must be trusted in Homebrew 7: `tap "owner/repo", trusted: true`.
- **Containers:** OrbStack is free for personal use only. For work use, buy a licence or switch to Colima in the `Brewfile`.
- **Dock:** `./cleanup-apps.sh --reset-dock` replaces the Dock with Ghostty, Android Studio, VS Code, Chrome and System Settings. It backs up the Dock first and prints the undo command.

## Rollback

```bash
./restore-defaults.sh                      # tweaked keys back to Apple's defaults; asks before power and system steps
./restore-defaults.sh --list-backups       # recorded snapshots; "original" is the state before the first run
./restore-defaults.sh --from-backup ~/.mac-android-dev-setup/backups/original
```

`--from-backup` touches only the keys the tweaks wrote: each goes back to its recorded value, or is deleted if it did not exist then. Macs tweaked by the 2025 scripts have no pre-tweak snapshot, so use the plain factory mode there.

Apps removed by `cleanup-apps.sh` are in the Trash as `<App> <timestamp>.app`: drag them back to `/Applications` and rename them, or re-download them from the App Store. Homebrew packages are left alone.

## Compatibility

- **Hardware:** Apple silicon only. macOS 27, Xcode 27 and Homebrew 7 no longer support Intel Macs.
- **macOS:** Sequoia 15, Tahoe 26, Golden Gate 27. Tested on 27.0 (build 26A428).
- **SIP:** stays enabled; nothing here needs it off.
- **Managed (MDM) Macs:** supported. Settings your organisation enforces, such as software updates, are reported by the check script and never overridden.

## License

MIT

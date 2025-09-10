#!/bin/bash

# Cleanup unwanted macOS applications

print_step() {
    echo -e "\033[0;34m==>\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m✓\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m⚠\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m✗\033[0m $1"
}

# Function to clean up app leftovers
clean_app_leftovers() {
    local app_name="$1"
    local bundle_id="$2"
    
    # Remove preference files
    rm -rf ~/Library/Preferences/*"${app_name}"* 2>/dev/null || true
    if [[ -n "$bundle_id" ]]; then
        rm -rf ~/Library/Preferences/"${bundle_id}".plist 2>/dev/null || true
    fi
    
    # Remove application support data
    rm -rf ~/Library/Application\ Support/*"${app_name}"* 2>/dev/null || true
    
    # Remove caches
    rm -rf ~/Library/Caches/*"${app_name}"* 2>/dev/null || true
    if [[ -n "$bundle_id" ]]; then
        rm -rf ~/Library/Caches/"${bundle_id}" 2>/dev/null || true
    fi
    
    # Remove containers (sandboxed apps)
    rm -rf ~/Library/Containers/*"${app_name}"* 2>/dev/null || true
    if [[ -n "$bundle_id" ]]; then
        rm -rf ~/Library/Containers/"${bundle_id}" 2>/dev/null || true
    fi
}

# Apps to remove (comment out any you want to keep)
APPS_TO_REMOVE=(
    "GarageBand.app"
    "iMovie.app"
    "Numbers.app"
    "Pages.app"
    "Chess.app"
    "DVD Player.app"
    "Photo Theater.app"
    "Stickies.app"
    "TextEdit.app"
    "Calendar.app"
    "Contacts.app"
    "FaceTime.app"
    "Mail.app"
    "Maps.app"
    "Messages.app"
    "Music.app"
    "News.app"
    "Notes.app"
    "Photos.app"
    "Podcasts.app"
    "Reminders.app"
    "Stocks.app"
    "TV.app"
    "Voice Memos.app"
    "Weather.app"
    "Time Machine.app"
    "Books.app"
    "Freeform.app"
)

print_step "Cleaning up unwanted applications..."

for app in "${APPS_TO_REMOVE[@]}"; do
    app_path="/Applications/${app}"
    if [[ -d "$app_path" ]]; then
        print_step "Removing ${app}..."
        if sudo rm -rf "$app_path"; then
            print_success "Removed ${app}"
            
            # Clean up leftover files
            app_name="${app%.app}"  # Remove .app extension
            print_step "Cleaning up ${app_name} leftovers..."
            clean_app_leftovers "$app_name"
            print_success "Cleaned up ${app_name} leftovers"
        else
            print_error "Failed to remove ${app}"
        fi
    else
        print_warning "${app} not found, skipping"
    fi
done

# Remove unwanted services/daemons (be careful with these)
print_step "Disabling unwanted services..."

# Disable Spotlight indexing for non-essential locations
sudo mdutil -a -i off
sudo mdutil -a -i on /  # Re-enable for root only

# Disable various services
SERVICES_TO_DISABLE=(
    "com.apple.netbiosd"        # NetBIOS
    "com.apple.AirPlayXPCHelper" # AirPlay
    "com.apple.rcd"             # Remote CD/DVD
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if launchctl list | grep -q "$service"; then
        print_step "Disabling ${service}..."
        sudo launchctl unload -w "/System/Library/LaunchDaemons/${service}.plist" 2>/dev/null || \
        launchctl unload -w "/System/Library/LaunchAgents/${service}.plist" 2>/dev/null || \
        print_warning "Could not disable ${service}"
    fi
done

# Disable unnecessary features
print_step "Disabling unnecessary features..."

# Disable Siri
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

# Disable Game Center
defaults write com.apple.gamed Disabled -bool true

# Disable automatic app downloads and updates (performance & privacy)
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write com.apple.commerce AutoUpdate -bool false
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 0

# Disable crash reporter and analytics
defaults write com.apple.CrashReporter DialogType none
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false

# Disable Handoff and Continuity (battery drains)
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false

# Disable AirDrop discovery (battery saver)
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true

# Disable Time Machine auto backup prompts
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable iCloud document sync
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Clean up dock
print_step "Cleaning up Dock..."
defaults write com.apple.dock persistent-apps -array

# Keep only essential apps in dock
DOCK_APPS=(
    "/Applications/iTerm.app"
    "/Applications/Visual Studio Code.app"
    "/Applications/Google Chrome.app"
    "/Applications/Marta.app"
    "/Applications/JetBrains Toolbox.app"
    "/System/Applications/System Settings.app"
)

for app in "${DOCK_APPS[@]}"; do
    if [[ -d "$app" ]]; then
        defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${app}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
done

# Restart Dock to apply changes
killall Dock

print_success "Application cleanup completed"
print_step "Dock has been reset with essential apps only"
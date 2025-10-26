#!/bin/bash

# Restore macOS to Default Settings
# This script reverses changes made by macos-tweaks.sh and cleanup-apps.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning "This script will restore macOS default settings"
print_warning "This will reverse changes made by macos-tweaks.sh"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Restore cancelled"
    exit 1
fi

print_step "Starting restore of macOS default settings..."

# Restore Dock settings
print_step "Restoring Dock settings..."
defaults write com.apple.dock autohide -bool false
defaults write com.apple.dock autohide-delay -float 0.5
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock orientation bottom
defaults write com.apple.dock tilesize -int 64
defaults write com.apple.dock show-recents -bool true
print_success "Dock settings restored"

# Restore Finder settings
print_step "Restoring Finder settings..."
defaults write com.apple.finder ShowPathbar -bool false
defaults write com.apple.finder ShowStatusBar -bool false
defaults write com.apple.finder FXDefaultSearchScope -string "SCev"  # Search entire Mac
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool false
print_success "Finder settings restored"

# Restore keyboard settings
print_step "Restoring keyboard settings..."
defaults write NSGlobalDomain KeyRepeat -int 6
defaults write NSGlobalDomain InitialKeyRepeat -int 25
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool true
print_success "Keyboard settings restored"

# Restore trackpad settings
print_step "Restoring trackpad settings..."
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool false
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 0
print_success "Trackpad settings restored"

# Restore text input settings
print_step "Restoring text input settings..."
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool true
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true
print_success "Text input settings restored"

# Re-enable Spotlight indexing
print_step "Re-enabling Spotlight indexing..."
sudo mdutil -a -i on
print_success "Spotlight indexing enabled"

# Re-enable photo analysis
print_step "Re-enabling photo analysis..."
defaults write com.apple.photoanalysisd enabled -bool true
print_success "Photo analysis enabled"

# Re-enable user services
print_step "Re-enabling user services..."
USER_ID=$(id -u)

USER_SERVICES=(
    "com.apple.parsecd"
    "com.apple.knowledge-agent"
    "com.apple.assistantd"
)

for service in "${USER_SERVICES[@]}"; do
    print_step "Enabling user service ${service}..."
    launchctl enable "gui/${USER_ID}/${service}" 2>/dev/null || true
done
print_success "User services re-enabled"

# Restore energy settings
print_step "Restoring energy settings..."
sudo pmset -a displaysleep 10
sudo pmset -a sleep 10
sudo pmset -a disksleep 10
sudo pmset -a hibernatemode 0
sudo pmset -a standby 1
sudo pmset -a powernap 1
sudo pmset -a tcpkeepalive 1
sudo pmset -a sms 1
sudo pmset -a gpuswitch 2
print_success "Energy settings restored"

# Re-enable Siri
print_step "Re-enabling Siri..."
defaults write com.apple.assistant.support "Assistant Enabled" -bool true
defaults write com.apple.Siri StatusMenuVisible -bool true
defaults write com.apple.Siri UserHasDeclinedEnable -bool false
print_success "Siri re-enabled"

# Re-enable automatic updates
print_step "Re-enabling automatic updates..."
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true
defaults write com.apple.commerce AutoUpdate -bool true
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
print_success "Automatic updates re-enabled"

# Re-enable crash reporter
print_step "Re-enabling crash reporter and analytics..."
defaults write com.apple.CrashReporter DialogType default
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool true
print_success "Crash reporter re-enabled"

# Re-enable Handoff
print_step "Re-enabling Handoff and Continuity..."
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool true
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool true
print_success "Handoff re-enabled"

# Re-enable AirDrop
print_step "Re-enabling AirDrop..."
defaults write com.apple.NetworkBrowser DisableAirDrop -bool false
print_success "AirDrop re-enabled"

# Re-enable Time Machine prompts
print_step "Re-enabling Time Machine prompts..."
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool false
print_success "Time Machine prompts re-enabled"

# Re-enable iCloud document sync
print_step "Re-enabling iCloud document sync..."
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool true
print_success "iCloud document sync re-enabled"

# Re-enable Game Center
print_step "Re-enabling Game Center..."
defaults write com.apple.gamed Disabled -bool false
print_success "Game Center re-enabled"

# Restore battery optimizations
print_step "Restoring battery optimization defaults..."
defaults write com.apple.appstore WebKitAutomaticPushNotificationEnabled -bool true
defaults write com.apple.appstoreagent AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.apsd Enabled -bool true 2>/dev/null || true
sudo defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool true 2>/dev/null || true
sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 1 2>/dev/null || true
defaults write com.apple.universalaccess reduceTransparency -bool false
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool true 2>/dev/null || true
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool true 2>/dev/null || true
print_success "Battery optimizations restored"

# Restart affected applications
print_step "Restarting affected applications..."
for app in "Dock" "Finder" "SystemUIServer"; do
    killall "${app}" &> /dev/null || true
done

print_success "macOS settings restored to defaults!"
print_warning "Some changes require a full system restart to take effect"
print_step "Please restart your Mac when convenient"

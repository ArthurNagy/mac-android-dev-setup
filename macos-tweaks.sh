#!/bin/bash

# macOS System Tweaks for Linux-like experience

print_step() {
    echo -e "\033[0;34m==>\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m✓\033[0m $1"
}

print_step "Applying macOS system tweaks..."

# Dock tweaks
print_step "Configuring Dock..."
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock orientation left
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false

# Finder tweaks
print_step "Configuring Finder..."
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"  # Search current folder
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Disable creation of .DS_Store files on network drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Screenshot tweaks
print_step "Configuring screenshots..."
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Create Screenshots directory
mkdir -p "$HOME/Desktop/Screenshots"

# Keyboard and input tweaks
print_step "Configuring keyboard..."
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Trackpad tweaks
print_step "Configuring trackpad..."
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Menu bar tweaks
print_step "Configuring menu bar..."
defaults write com.apple.menuextra.clock DateFormat -string "EEE MMM d  H:mm:ss"
defaults write NSGlobalDomain _HIHideMenuBar -bool false

# Disable annoying features
print_step "Disabling annoying features..."
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false


# Disable heavy background services for performance and battery
print_step "Disabling unnecessary background services..."

# Disable Spotlight indexing for better performance (keep only root)
sudo mdutil -a -i off
sudo mdutil -a -i on /

# Disable photo analysis (heavy CPU usage)
defaults write com.apple.photoanalysisd enabled -bool false

# Disable various Apple ecosystem services
SERVICES_TO_DISABLE=(
    "com.apple.bird"            # CloudKit/iCloud sync
    "com.apple.parsecd"         # Spotlight suggestions
    "com.apple.knowledge-agent" # Siri knowledge base
    "com.apple.assistantd"      # Siri assistant
    "com.apple.CallHistoryPluginHelper" # Call history sync
    "com.apple.CallHistorySyncHelper"   # Call history sync
    "com.apple.cloudd"          # iCloud daemon
    "com.apple.cloudpaird"      # iCloud pairing
    "com.apple.cloudphotod"     # iCloud Photos
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

# Terminal tweaks
print_step "Configuring Terminal..."
defaults write com.apple.terminal StringEncodings -array 4
defaults write com.apple.terminal Shell -string "/bin/zsh"

# Activity Monitor tweaks
print_step "Configuring Activity Monitor..."
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor IconType -int 5
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# Energy settings for maximum battery life and performance
print_step "Configuring energy settings..."
sudo pmset -a displaysleep 15
sudo pmset -a sleep 30          # Auto sleep after 30 minutes (good for battery)
sudo pmset -a disksleep 10      # Disk sleep after 10 minutes
sudo pmset -a hibernatemode 3   # Enable hibernation (saves battery on long sleep)
sudo pmset -a standby 1         # Enable standby mode (ultra-low power)
sudo pmset -a standbydelayhigh 86400  # 24 hours before standby on AC
sudo pmset -a standbydelaylow 3600    # 1 hour before standby on battery
sudo pmset -a autopoweroff 1    # Enable auto power off (saves battery)
sudo pmset -a powernap 0        # Disable Power Nap (background activity - battery drain)
sudo pmset -a tcpkeepalive 0    # Disable wake for network access

# Disable sudden motion sensor (not needed on SSDs)
sudo pmset -a sms 0

# GPU power management (force integrated graphics when possible)
sudo pmset -a gpuswitch 0

# Restart affected applications
print_step "Restarting affected applications..."
for app in "Dock" "Finder" "SystemUIServer" "Terminal"; do
    killall "${app}" &> /dev/null || true
done

print_success "System tweaks applied successfully"
print_step "Some changes may require a restart to take effect"
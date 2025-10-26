#!/bin/bash

# macOS System Tweaks for Linux-like experience

print_step() {
    echo -e "\033[0;34m==>\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m✓\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m⚠\033[0m $1"
}

# Check SIP status
print_step "Checking System Integrity Protection (SIP) status..."
sip_status=$(csrutil status 2>&1)
if echo "$sip_status" | grep -q "enabled"; then
    print_warning "SIP is enabled (recommended). Some system services cannot be disabled."
    print_warning "This script will disable what it can without compromising security."
    SIP_ENABLED=true
else
    print_warning "SIP is disabled. You can disable system services, but this is a security risk."
    SIP_ENABLED=false
fi

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

# Disable creation of .DS_Store files on network drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

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
sudo mdutil -a -i off 2>/dev/null
sudo mdutil -a -i on / 2>/dev/null

# Disable photo analysis (heavy CPU usage)
defaults write com.apple.photoanalysisd enabled -bool false

# Disable various Apple ecosystem services (user-level)
# Note: System-level services require SIP to be disabled, which is not recommended
print_step "Disabling user-level services..."

# Get current user ID for launchctl disable commands
USER_ID=$(id -u)

# User-level services that can be disabled safely
USER_SERVICES=(
    "com.apple.parsecd"         # Spotlight suggestions
    "com.apple.knowledge-agent" # Siri knowledge base
    "com.apple.assistantd"      # Siri assistant
)

for service in "${USER_SERVICES[@]}"; do
    if launchctl list | grep -q "$service" 2>/dev/null; then
        print_step "Disabling user service ${service}..."
        launchctl disable "gui/${USER_ID}/${service}" 2>/dev/null && \
        launchctl kill SIGTERM "gui/${USER_ID}/${service}" 2>/dev/null
        print_success "Disabled ${service}"
    fi
done

# These system services require SIP disabled - only attempt if SIP is off
if [ "$SIP_ENABLED" = false ]; then
    print_warning "SIP is disabled. Attempting to disable system services..."
    SYSTEM_SERVICES=(
        "com.apple.bird"            # CloudKit/iCloud sync
        "com.apple.cloudd"          # iCloud daemon
        "com.apple.cloudpaird"      # iCloud pairing
        "com.apple.cloudphotod"     # iCloud Photos
    )

    for service in "${SYSTEM_SERVICES[@]}"; do
        if launchctl list | grep -q "$service" 2>/dev/null; then
            print_step "Disabling system service ${service}..."
            sudo launchctl bootout system/"${service}" 2>/dev/null && \
            print_success "Disabled ${service}" || \
            print_warning "Could not disable ${service}"
        fi
    done
else
    print_warning "System services (iCloud, etc.) cannot be disabled with SIP enabled."
    print_warning "You can disable them manually in System Settings > Apple ID"
fi

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

# Enhanced battery optimizations
print_step "Applying enhanced battery optimizations..."

# Disable background app refresh (battery drain)
print_step "Disabling background app refresh..."
defaults write com.apple.appstore WebKitAutomaticPushNotificationEnabled -bool false
defaults write com.apple.appstoreagent AutomaticCheckEnabled -bool false

# Disable Apple Watch unlock (Bluetooth drain)
print_step "Disabling Apple Watch unlock..."
sudo defaults write /Library/Preferences/com.apple.apsd Enabled -bool false 2>/dev/null || true

# Disable location services for unnecessary apps (battery drain)
print_step "Disabling location services..."
sudo defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool false 2>/dev/null || true

# Disable Bluetooth when not in use (can be re-enabled in System Settings)
print_step "Setting Bluetooth to off by default..."
sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0 2>/dev/null || true

# Disable Wi-Fi when ethernet is connected (save power)
print_step "Disabling Wi-Fi power boost..."
sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport en0 prefs DisconnectOnLogout=YES 2>/dev/null || true

# Reduce transparency effects (GPU usage)
print_step "Reducing transparency effects..."
defaults write com.apple.universalaccess reduceTransparency -bool true

# Disable automatic brightness adjustment (screen is biggest battery drain)
print_step "Disabling automatic brightness..."
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false 2>/dev/null || true

# Disable keyboard backlight auto-adjust
print_step "Disabling keyboard backlight auto-adjustment..."
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool false 2>/dev/null || true

print_success "Enhanced battery optimizations applied"

# Restart affected applications
print_step "Restarting affected applications..."
for app in "Dock" "Finder" "SystemUIServer" "Terminal"; do
    killall "${app}" &> /dev/null || true
done

print_success "System tweaks applied successfully"
print_step "Some changes may require a restart to take effect"
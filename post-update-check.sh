#!/bin/bash

# Post-Update Configuration Check Script
# Run this after macOS updates or when you suspect settings have been reset

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

print_step "Checking macOS configuration after update..."

# Check for unwanted apps that may have returned
print_step "Checking for reinstalled bloatware apps..."
UNWANTED_APPS=(
    "GarageBand.app" "iMovie.app" "Numbers.app" "Pages.app"
    "Chess.app" "DVD Player.app" "Photo Theater.app" "Stickies.app"
    "Calendar.app" "Contacts.app" "FaceTime.app" "Mail.app"
    "Maps.app" "Messages.app" "Music.app" "News.app" "Notes.app"
    "Photos.app" "Podcasts.app" "Reminders.app" "Stocks.app"
    "TV.app" "Voice Memos.app" "Weather.app" "Books.app" "Freeform.app"
    "Home.app" "Shortcuts.app" "QuickTime Player.app" "Dictionary.app"
    "Font Book.app" "Image Capture.app" "Migration Assistant.app"
)

apps_found=0
for app in "${UNWANTED_APPS[@]}"; do
    if [[ -d "/Applications/${app}" ]]; then
        print_warning "Found reinstalled app: ${app}"
        apps_found=1
    fi
done

if [[ $apps_found -eq 0 ]]; then
    print_success "No unwanted apps found"
else
    print_error "Run cleanup-apps.sh to remove reinstalled bloatware"
fi

# Check system services that commonly get re-enabled
print_step "Checking system services..."
SERVICES_TO_CHECK=(
    "com.apple.bird"            # CloudKit/iCloud sync
    "com.apple.parsecd"         # Spotlight suggestions  
    "com.apple.knowledge-agent" # Siri knowledge base
    "com.apple.assistantd"      # Siri assistant
    "com.apple.cloudd"          # iCloud daemon
    "com.apple.cloudphotod"     # iCloud Photos
)

services_running=0
for service in "${SERVICES_TO_CHECK[@]}"; do
    if launchctl list | grep -q "$service"; then
        print_warning "Service re-enabled: ${service}"
        services_running=1
    fi
done

if [[ $services_running -eq 0 ]]; then
    print_success "All targeted services remain disabled"
else
    print_error "Run macos-tweaks.sh to re-disable services"
fi

# Check critical settings
print_step "Checking critical system settings..."

# Check Spotlight indexing
if mdutil -s / | grep -q "Indexing enabled"; then
    spotlight_status="enabled"
else
    spotlight_status="disabled" 
fi

if [[ "$spotlight_status" == "enabled" ]]; then
    print_warning "Spotlight indexing is enabled (may impact performance)"
else
    print_success "Spotlight indexing properly configured"
fi

# Check Gatekeeper status
gatekeeper_status=$(spctl --status | awk '{print $2}')
if [[ "$gatekeeper_status" == "enabled" ]]; then
    print_success "Gatekeeper is enabled (good security)"
else
    print_warning "Gatekeeper is disabled"
fi

# Check Power Nap status
powernap_ac=$(pmset -g | grep "powernap" | awk '{print $2}')
if [[ "$powernap_ac" == "0" ]]; then
    print_success "Power Nap is disabled (good for battery)"
else
    print_warning "Power Nap is enabled (may drain battery)"
fi

# Check automatic updates
auto_check=$(defaults read com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "1")
if [[ "$auto_check" == "0" ]]; then
    print_success "Automatic update checking is disabled"
else
    print_warning "Automatic update checking is enabled"
fi

# Check analytics
analytics_status=$(defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo "1")
if [[ "$analytics_status" == "0" ]]; then
    print_success "Analytics submission is disabled"
else
    print_warning "Analytics submission is enabled"
fi

print_step "Configuration check complete!"
echo ""
echo "Actions needed:"
if [[ $apps_found -eq 1 ]]; then
    echo "• Run: bash cleanup-apps.sh"
fi
if [[ $services_running -eq 1 ]]; then
    echo "• Run: bash macos-tweaks.sh"
fi
if [[ "$spotlight_status" == "enabled" ]] || [[ "$powernap_ac" != "0" ]] || [[ "$auto_check" != "0" ]] || [[ "$analytics_status" != "0" ]]; then
    echo "• Run: bash macos-tweaks.sh (to fix settings)"
fi

if [[ $apps_found -eq 0 ]] && [[ $services_running -eq 0 ]] && [[ "$spotlight_status" == "disabled" ]] && [[ "$powernap_ac" == "0" ]] && [[ "$auto_check" == "0" ]] && [[ "$analytics_status" == "0" ]]; then
    print_success "All configurations look good! No action needed."
fi
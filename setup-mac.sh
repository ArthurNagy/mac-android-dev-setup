#!/bin/bash

# MacBook Apple Silicon Android Development Setup Script
# Run with: bash setup-mac.sh

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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only"
    exit 1
fi

# Check for Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    print_warning "This script is optimized for Apple Silicon Macs"
fi

print_step "Starting MacBook Pro Android development setup..."

# Install Command Line Tools
print_step "Installing Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    xcode-select --install
    print_warning "Please complete the Xcode Command Line Tools installation and run this script again"
    exit 1
else
    print_success "Xcode Command Line Tools already installed"
fi

# Install Homebrew
print_step "Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    
    print_success "Homebrew installed"
else
    print_success "Homebrew already installed"
    brew update
fi

# Install packages via Homebrew
print_step "Installing packages via Homebrew..."
if [[ -f "Brewfile" ]]; then
    print_success "Found Brewfile, installing packages from bundle..."
    brew bundle install --file=Brewfile
else
    print_step "No Brewfile found, installing essential packages for Android development..."
    
    # Essential CLI tools
    brew install \
        coreutils findutils gnu-tar gnu-sed gawk gnutls gnu-getopt grep \
        git curl wget tree htop neofetch \
        neovim tmux zsh-autosuggestions zsh-syntax-highlighting \
        fzf ripgrep fd bat exa delta \
        node python@3.11 \
        scrcpy adb-enhanced jq
    
    # GUI Applications
    brew install --cask \
        iterm2 rectangle raycast visual-studio-code \
        hiddenbar appcleaner jetbrains-toolbox \
        google-chrome marta
    
    # Install Xcode from Mac App Store (required for Android development)
    if command -v mas &> /dev/null; then
        print_step "Installing Xcode from Mac App Store..."
        mas install 497799835  # Xcode
    else
        print_warning "mas-cli not found. Please install Xcode manually from the Mac App Store"
    fi
fi

print_success "Packages installed"

# Setup shell (Oh My Zsh)
print_step "Setting up shell environment..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install useful plugins
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    # Setup .zshrc for Android development
    if [[ -f "$HOME/.zshrc" ]]; then
        print_warning "Backing up existing .zshrc to .zshrc.backup"
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    
    cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting macos)
source $ZSH/oh-my-zsh.sh

# Homebrew (Apple Silicon)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# GNU tools priority
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gawk/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-getopt/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"

# Editor
export EDITOR="nvim"
export VISUAL="nvim"

# Android Development
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH"

# Java for Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

# Aliases
alias ll='exa -la --icons'
alias la='exa -a --icons'
alias ls='exa --icons'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias vim='nvim'
alias vi='nvim'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias reload='source ~/.zshrc'
alias brewup='brew update && brew upgrade && brew cleanup'

# More Linux-like aliases
alias ll='exa -la --icons --git'
alias la='exa -a --icons'
alias l='exa --icons'
alias lst='exa --tree --icons'
alias llt='exa -la --tree --icons --git'

# System information (Linux-style)
alias lscpu='sysctl -n machdep.cpu.brand_string'
alias lsusb='system_profiler SPUSBDataType'
alias lspci='system_profiler SPPCIDataType'
alias mount='mount | column -t'

# Network aliases (Linux-style)
alias ports='lsof -i -P -n | grep LISTEN'
alias listening='lsof -i -P | grep LISTEN'
alias netstat='netstat -tulpn'
alias myip='curl -s https://httpbin.org/ip | jq -r .origin'
alias localip='ipconfig getifaddr en0 || ipconfig getifaddr en1'
alias ips='ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d " " -f2'
alias flush='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'

# Process management
alias psg='ps aux | grep'
alias topcpu='ps aux | sort -k3 -nr | head -10'
alias topmem='ps aux | sort -k4 -nr | head -10'

# Package management (Linux-style)
alias install='brew install'
alias remove='brew uninstall'
alias search='brew search'
alias update='brew update && brew upgrade'
alias upgrade='brew upgrade'
alias list='brew list'
alias info='brew info'

# System maintenance (Linux-like)
alias sysupdate='sudo softwareupdate -i -a; brew update && brew upgrade && brew cleanup; mas upgrade'
alias sysclean='brew cleanup --prune=all && brew autoremove; sudo periodic daily weekly monthly'
alias sysinfo='neofetch; df -h; vm_stat'

# Service management (systemd-like aliases)
alias services='launchctl list'
alias service-start='launchctl load'
alias service-stop='launchctl unload'

mkcd() { mkdir -p "$1" && cd "$1" }
EOF
    
    print_success "Oh My Zsh and basic config installed"
else
    print_success "Oh My Zsh already installed"
fi

# macOS system tweaks
print_step "Applying macOS tweaks..."
bash macos-tweaks.sh

# Cleanup default apps
print_step "Cleaning up unwanted applications..."
bash cleanup-apps.sh

print_success "Setup complete! Please restart your terminal or run 'source ~/.zshrc'"
print_step "Next steps:"
echo "1. Open JetBrains Toolbox and install Android Studio"
echo "2. Configure Rectangle window management shortcuts"
echo "3. Set up Android SDK path in Android Studio"
echo "4. Configure Raycast hotkeys"
echo "5. Install any additional Android Studio plugins you need"
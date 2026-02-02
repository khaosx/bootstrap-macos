#!/usr/bin/env zsh

# bootstrap_macos.sh - macOS Post-Installation (1Password + Power + Automagic Location)
# Optimized for Apple Silicon (M-Series) on macOS Tahoe
# Author: Kristopher Newman

# --- Configuration & Constants ---
readonly PROJECTS_DIR="$HOME/projects"
readonly DOTFILES_DIR="$PROJECTS_DIR/dotfiles"
readonly DOTFILES_REPO="https://github.com/khaosx/dotfiles"
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# 1Password Paths
readonly OP_NAME_PATH="op://khaosx-infrastructure/Bootstrap Silicon/system_formal_name"
readonly OP_TZ_PATH="op://khaosx-infrastructure/khaosx.io Site Secrets/site_tz"

SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::' | xargs)

# --- Logging Functions ---
log_info()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $1"; }
log_warn()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $1" >&2; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2; }

# --- Helper Functions ---
keep_sudo_alive() {
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

check_full_disk_access() {
    log_info "Checking for Full Disk Access..."
    if ! sudo ls "/Library/Application Support/com.apple.TCC" &>/dev/null; then
        log_warn "Full Disk Access is NOT enabled for this terminal."
        echo "--------------------------------------------------------------"
        echo "ACTION REQUIRED: Full Disk Access"
        echo "1. System Settings will now open to Privacy & Security > Full Disk Access."
        echo "2. Find your Terminal application and toggle the switch to ON."
        echo "3. If prompted, Relaunch the terminal and run this script again."
        echo "--------------------------------------------------------------"
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        printf "Press [Enter] to exit and restart your terminal..." > /dev/tty
        read -r _ < /dev/tty
        exit 1
    fi
    log_info "Full Disk Access verified."
}

# --- 1Password & Core Setup ---

install_1password_prerequisites() {
    log_info "Ensuring Homebrew is installed..."
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    log_info "Installing 1Password (App) and 1Password CLI..."
    brew install --cask 1password
    brew install 1password-cli

    echo "\n--------------------------------------------------------------"
    echo "ACTION REQUIRED: 1Password Setup"
    echo "1. Open the 1Password App and sign in."
    echo "2. Go to Settings > Developer."
    echo "3. Enable 'Integrate with 1Password CLI'."
    echo "--------------------------------------------------------------\n"
    
    printf "Press [Enter] once you have enabled CLI integration..." > /dev/tty
    read -r _ < /dev/tty

    until op account list &>/dev/null; do
        log_warn "Still can't talk to 1Password. Ensure 'Integrate with 1Password CLI' is ON."
        printf "Press [Enter] to try again..." > /dev/tty
        read -r _ < /dev/tty
    done
    log_info "1Password CLI integration verified."
}

# --- Workspace & Dotfiles Setup ---

setup_projects_and_dotfiles() {
    log_info "Creating projects directory at $PROJECTS_DIR..."
    mkdir -p "$PROJECTS_DIR"

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_info "Cloning dotfiles from $DOTFILES_REPO..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        log_info "Dotfiles directory already exists."
    fi
}

deploy_dotfiles() {
    log_info "Deploying static dotfiles..."
    cp -f "$DOTFILES_DIR/sh.Brewfile" "$HOME/.Brewfile"
    cp -f "$DOTFILES_DIR/git.gitconfig" "$HOME/.gitconfig"
    cp -f "$DOTFILES_DIR/git.gitignore" "$HOME/.gitignore"
    cp -f "$DOTFILES_DIR/git.gitmessage" "$HOME/.gitmessage"
    cp -f "$DOTFILES_DIR/ansible.ansible-lint" "$HOME/.ansible-lint"

    log_info "Processing templates via 1Password CLI..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Using -f to ensure current session secrets overwrite any stale files
    op inject -f -i "$DOTFILES_DIR/ssh.config.tpl" -o "$HOME/.ssh/config"
    op inject -f -i "$DOTFILES_DIR/zsh.aliases.tpl" -o "$HOME/.aliases"
    op inject -f -i "$DOTFILES_DIR/zsh.zprofile.tpl" -o "$HOME/.zprofile"
    op inject -f -i "$DOTFILES_DIR/zsh.zshrc.tpl" -o "$HOME/.zshrc"

    chmod 600 "$HOME/.ssh/config"
}

# --- System & Power Configuration ---

apply_system_settings() {
    log_info "Setting system identifiers to: $COMPUTER_NAME"
    sudo scutil --set ComputerName "$COMPUTER_NAME"
    sudo scutil --set HostName "$HOST_NAME"
    sudo scutil --set LocalHostName "$HOST_NAME"

    log_info "Applying UI/UX defaults..."

    # NSGlobalDomain Enhancements
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticQuotesSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
    defaults write NSGlobalDomain NSDocumentsSaveNewDocumentsToCloud -bool false
    defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
    
    # Finder & System
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    defaults write com.apple.loginwindow TALLogoutSavesState -bool false
    
    # --- Time and Location Services ---
    log_info "Configuring Location and Time Services..."
    if [[ $(sudo defaults read /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled 2>/dev/null) != "1" ]]; then
        log_warn "Location Services global toggle is OFF."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        printf "Press [Enter] once you have toggled Location Services ON in System Settings..." > /dev/tty
        read -r _ < /dev/tty
    fi

    # Apply automagic settings
    sudo /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -int 1
    local uuid=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Hardware UUID" | cut -c22-57)
    sudo /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$uuid LocationServicesEnabled -int 1

    sudo /usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool YES
    sudo /usr/bin/defaults write /private/var/db/timed/Library/Preferences/com.apple.timed.plist TMAutomaticTimeOnlyEnabled -bool YES
    sudo /usr/bin/defaults write /private/var/db/timed/Library/Preferences/com.apple.timed.plist TMAutomaticTimeZoneEnabled -bool YES
    
    if [[ -n "$TIME_ZONE" ]]; then
        sudo systemsetup -settimezone "$TIME_ZONE" > /dev/null
    fi
    sudo /usr/sbin/systemsetup -setusingnetworktime on > /dev/null
    sudo killall timed &>/dev/null || true
}

apply_power_settings() {
    log_info "Applying power management settings..."
    sudo pmset -c sleep 30 displaysleep 25 disksleep 30 hibernatemode 0 lessbright 0
    sudo pmset -b sleep 15 displaysleep 15 disksleep 15 hibernatemode 3 acwake 1 lessbright 1
    
    defaults write com.apple.PowerChime ChimeOnAllHardware -bool true
    open /System/Library/CoreServices/PowerChime.app &>/dev/null || true
}

# --- Main Execution Flow ---

set -e
clear

log_info "Starting macOS Bootstrap (Apple Silicon + Tahoe Edition)"

sudo -v
keep_sudo_alive
check_full_disk_access

install_1password_prerequisites

log_info "Fetching identity details from 1Password..."
COMPUTER_NAME=$(op read "$OP_NAME_PATH")
TIME_ZONE=$(op read "$OP_TZ_PATH")
HOST_NAME=$(echo "$COMPUTER_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

setup_projects_and_dotfiles
deploy_dotfiles
apply_system_settings
apply_power_settings

brew analytics off
if [[ -f "$HOME/.Brewfile" ]]; then
    log_info "Installing packages from $HOME/.Brewfile..."
    brew bundle --file="$HOME/.Brewfile" || log_warn "Brew bundle completed with some errors."
    brew cleanup
fi

if command -v ansible-galaxy &> /dev/null; then
    log_info "Installing Ansible collections..."
    ansible-galaxy collection install community.general
fi

log_info "Bootstrap complete! Environment ready."
killall Finder &>/dev/null || true

unset COMPUTER_NAME HOST_NAME TIME_ZONE
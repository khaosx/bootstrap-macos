#!/usr/bin/env zsh

# bootstrap_macos.sh - macOS Post-Installation Configuration

# Author: Kristopher Newman
# Date: 2025-02-06

# Load Configuration
CONFIG_FILE="./config.cfg"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file not found. Exiting."
    exit 1
fi

# Constants
readonly SUDO_KEEPALIVE_TIMEOUT=300 # Seconds (5 minutes)
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::' | xargs) # Trim whitespace

# Logging Functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

# Functions

keep_sudo_alive() {
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

validate_time_zone() {
    if ! sudo systemsetup -listtimezones | grep -Fxq "$1"; then
        log_error "Invalid time zone: $1"
        exit 1
    fi
}

get_non_empty_input() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        printf "%s: " "$prompt" > /dev/tty
        read -r input < /dev/tty
        if [[ -z "$input" ]]; then
            echo "This field cannot be empty."
        fi
    done
    echo "$input"
}

prompt_mac_app_store_sign_in() {
    if [[ -z $(defaults read com.apple.storeagent AppleID) ]]; then
        echo "You're not signed into the Mac App Store."
        exit 1
    else
        echo "Mac App Store sign-in confirmed."
    fi
}

install_command_line_tools() {
    xcode-select -p &> /dev/null
    if [[ $? -ne 0 ]]; then
        log_info "Command Line Tools for Xcode not found. Installing..."
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
        softwareupdate -i "$PROD" --verbose
        if [[ $? -ne 0 ]]; then
            log_error "Failed to install Command Line Tools. Exiting."
            exit 1
        fi
    else
        log_info "Command Line Tools for Xcode already installed."
    fi
}

install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew."
        /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
    else
        log_info "Homebrew is already installed."
    fi
}

install_homebrew_packages() {
    if [[ -n "$HOMEBREW_BUNDLE_FILE" ]]; then
        log_info "Installing Homebrew packages from bundle."
        brew bundle --file="$HOMEBREW_BUNDLE_FILE"
        brew cleanup
    else
        log_info "No Homebrew bundle file specified. Please install applications manually."
        log_info "To avoid this step in the future, generate a Brewfile with:"
        log_info "brew bundle dump --file=$HOME/.Brewfile"
        log_info "Then set the environment variable HOMEBREW_BUNDLE_FILE=\"$HOME/.Brewfile\""
    fi
}

install_ansible_components() {
    log_info "Installing Ansible collections."
    ansible-galaxy collection install community.general
}

install_dotfiles() {
    log_info "Installing and linking dotfiles."
    chezmoi init --apply https://github.com/$GITHUB_USERNAME/dotfiles.git
}

apply_system_settings() {
    log_info "Setting system preferences."

    log_info "Setting system label and name."
    sudo scutil --set ComputerName "$COMPUTER_NAME"
    sudo scutil --set HostName "$HOST_NAME"
    sudo scutil --set LocalHostName "$HOST_NAME"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$HOST_NAME"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server ServerDescription -string "$COMPUTER_DESCRIPTION"

    log_info "Setting time zone to $TIME_ZONE."
    sudo systemsetup -settimezone "$TIME_ZONE" > /dev/null
}

# Main Script Logic
set -e
clear

log_info "Starting macOS post-installation configuration."

if [[ $(uname -s) != "Darwin" ]]; then
    log_error "This script only supports macOS. Exiting."
    exit 1
fi

sudo -v
keep_sudo_alive

log_info "Collecting setup information."

COMPUTER_NAME=$(get_non_empty_input "Enter a name for your Mac")
COMPUTER_OWNER=$(get_non_empty_input "Who is the primary user of this system?")
log_info "To view all time zones, run \`sudo systemsetup -listtimezones\`"
TIME_ZONE=$(get_non_empty_input "Enter your time zone")
validate_time_zone "$TIME_ZONE"

prompt_mac_app_store_sign_in

COMPUTER_DESCRIPTION="$COMPUTER_OWNER's $SYSDESC"
HOST_NAME=$(echo "$COMPUTER_NAME" | tr '[:upper:]' '[:lower:]')

log_info "Setup Information:"
log_info "Computer Name: $COMPUTER_NAME"
log_info "Computer Owner: $COMPUTER_OWNER"
log_info "Computer Description: $COMPUTER_DESCRIPTION"
log_info "Host Name: $HOST_NAME"
log_info "Time Zone: $TIME_ZONE"

log_info "Applying system settings."
apply_system_settings

install_command_line_tools
install_homebrew

eval "$(/opt/homebrew/bin/brew shellenv)" # Activate Homebrew in current shell
brew analytics off
brew doctor

install_dotfiles
install_homebrew_packages
install_ansible_components

log_info "macOS post-install script complete! Please restart your computer."

# Clean Up
unset COMPUTER_NAME COMPUTER_OWNER TIME_ZONE COMPUTER_DESCRIPTION HOST_NAME SYSDESC
rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

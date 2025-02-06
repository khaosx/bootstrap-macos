#!/usr/bin/env sh

################################################################################
# bootstrap_macos.sh
#
# usage: ./bootstrap_macos.sh <system_name>
#
# Script to be run after MacOS install to set preferences and install apps.
# Shamelessly stolen from https://github.com/joshukraine/ and modified by me.
# Odds are, this won't be useful to you except as a template to build your own.
# Feel free. Licensed under the "Good Luck With That" public license.
################################################################################

# Variables
BOOTSTRAP_REPO_URL="https://github.com/khaosx/bootstrap-macos.git"  # Or your preferred repo
BOOTSTRAP_DIR="$HOME/macos-setup"
DEFAULT_COMPUTER_OWNER="${USER:-$(whoami)}"     # Use current user if not set
DEFAULT_COMPUTER_NAME="${1:-${HOSTNAME%%.*}}"   # Use first parameter if exist, or hostname up to the first dot if not
DEFAULT_TIME_ZONE="America/New_York"
SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::' | xargs) # Trim whitespace

# Constants
readonly SUDO_KEEPALIVE_TIMEOUT=300 # Seconds (5 minutes)
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# Functions

## Function to keep sudo alive
sudo_keep_alive() {
    local timeout="${1:-$SUDO_KEEPALIVE_TIMEOUT}"
    local start_time=$(date +%s)
    while true; do
        sleep 60
        sudo -v &> /dev/null
        if [[ $? -ne 0 ]]; then
            echo "Sudo timestamp expired."
            return 1
        fi
        local elapsed_time=$(( $(date +%s) - start_time ))
        if (( elapsed_time >= timeout )); then
            echo "Sudo keep-alive timeout reached."
            return 1
        fi
    done & # Run in background
    local pid=$!
    wait $pid # Wait for the background process to avoid race conditions
    return 0
}

get_user_input() {
    local prompt="$1"
    local default_value="$2"
    local input
    printf "$prompt (Leave blank for default: %s)\n" "$default_value"
    read -r input
    echo "${input:-$default_value}"  # Return the input or default
}

install_command_line_tools() {
    xcode-select -p &> /dev/null
    if [[ $? -ne 0 ]]; then
        printf "Command Line Tools for Xcode not found. Installing from softwareupdate.\n"
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        local PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
        softwareupdate -i "$PROD" --verbose
        if [[ $? -ne 0 ]]; then
          echo "Failed to install command line tools. Exiting."
          exit 1
        fi
    else
        printf "Command Line Tools for Xcode have been installed.\n"
    fi
}

install_homebrew() {
  if ! command -v brew &> /dev/null; then # Check if brew is already installed
    printf "Installing Homebrew.\n"
    /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
    eval "$(/opt/homebrew/bin/brew shellenv)" # Activate in current shell
    brew analytics off
    brew doctor
  else
    echo "Homebrew is already installed."
  fi
  brew install chezmoi
}

install_brewfile() {
    printf "Installing base loadout.\n"
    brew bundle
    brew cleanup
}

install_ansible_components() {
    printf "Installing Ansible collections.\n"
    ansible-galaxy collection install community.general
}

install_dotfiles() {
    printf "Installing and linking dotfiles.\n"
    chezmoi init --apply $GITHUB_USERNAME
}

# Main script logic
clear
printf "*************************************************************************\\n"
printf "*******                                                           *******\\n"
printf "*******                 Post Install MacOS Config                 *******\\n"
printf "*******                                                           *******\\n"
printf "*************************************************************************\\n\\n"

printf "Verifying macOS is the operating system...\n"
[[ $(uname -s) != "Darwin" ]] && { echo "This script only supports macOS. Exiting."; exit 1; }
printf "OS Verified. You may be prompted to enter your password for sudo\n\n"

# Keep sudo alive in background
sudo_keep_alive

printf "\nNow, let's get some info about your setup.\n\n"

COMPUTER_NAME=$(get_user_input "Enter a name for your Mac" "$DEFAULT_COMPUTER_NAME")
COMPUTER_OWNER=$(get_user_input "Who is the primary user of this system?" "$DEFAULT_COMPUTER_OWNER")
TIME_ZONE=$(get_user_input "Enter your time zone" "$DEFAULT_TIME_ZONE")
printf "NOTE: To view all zones, run \`sudo systemsetup -listtimezones\`\n"

read -r "REPLY?Please sign in to the Mac App Store. Press Enter when done."

COMPUTER_DESCRIPTION="$COMPUTER_OWNER's $SYSDESC"
HOST_NAME=$(echo "$COMPUTER_NAME" | tr '[:upper:]' '[:lower:]')

clear
printf "Looks good. Here's what we've got so far.\\n"
printf "Bootstrap Script:       ==> $BOOTSTRAP_REPO_URL\\n"
printf "Bootstrap Directory:    ==> $BOOTSTRAP_DIR\\n"
printf "Computer Name:          ==> $COMPUTER_NAME\\n"
printf "Computer Description:   ==> $COMPUTER_DESCRIPTION\\n"
printf "Host Name:              ==> $HOST_NAME\\n"
printf "Time Zone:              ==> $TIME_ZONE\\n\\n"
read -r "CONFIRM?Continue? (y/n)" # More concise confirm prompt
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { printf "Exiting per user choice\n"; exit 1; }

printf "Applying basic system info\\n"

printf "Setting system label and name\\n"
sudo scutil --set ComputerName $COMPUTER_NAME
sudo scutil --set HostName $HOST_NAME
sudo scutil --set LocalHostName $HOST_NAME
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $HOST_NAME
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server ServerDescription -string "$COMPUTER_DESCRIPTION"

install_command_line_tools

install_homebrew

install_dotfiles

install_applications

install_ansible_components

printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
printf  "****                                                              ****\\n"
printf  "****            MacOS post-install script complete!               ****\\n"
printf  "****                Please restart your computer.                 ****\\n"
printf  "****                                                              ****\\n"
printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
exit 0

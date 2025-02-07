#!/usr/bin/env sh

# bootstrap_macos.sh - macOS Post-Installation Configuration

# Author: Kristopher Newman
# Date: 2025-02-06
#
# Description:
# This script automates common post-installation tasks for macOS, including
# configuring system settings, installing command-line tools, and setting up
# essential applications.  It is intended to streamline the setup process
# after a fresh macOS installation.
#
# Usage:
#   ./bootstrap_macos.sh [system_name]
#
# Arguments:
#   system_name (optional):  The name to assign to the Mac. If not provided,
#                            a default name will be used (see configuration
#                            section).
#
# Configuration:
#   Default values for various settings (e.g., computer name, owner,
#   time zone) are defined as variables within the script. These can be
#   modified directly in the script.  Consider using environment variables or
#   a separate configuration file for more complex setups.
#
# Dependencies:
#   - macOS (Darwin kernel)
#   - An active internet connection
#   - Xcode Command Line Tools (automatically installed if not present)
#   - Homebrew (automatically installed)
#   - Homebrew bundle continaing all dependencies for brew, mas, cask, etc (Optional, but reccomended)
#     - Generate with "brew bundle --file=$HOME/.Brewfile"
#     - Set with command export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"
#
# Notes:
#   - This script requires administrator privileges (sudo) to perform certain
#     actions.
#   - User interaction is required for some steps (e.g., Mac App Store sign-in).
#   - A system restart is recommended after the script completes.
#   - Error handling and input validation could be improved for greater
#     robustness.
#   - The application installation list is currently hardcoded. Consider making
#     this configurable (e.g., via a separate file or command-line options).
#   - This script draws inspiration from and adapts concepts from other
#     bootstrap scripts, including those available on GitHub.  Attribution for
#     specific components is provided within the script where applicable.
#
# License:
#   MIT License

# Variables
BOOTSTRAP_REPO_URL="https://github.com/khaosx/bootstrap-macos.git"  # Or your preferred repo
BOOTSTRAP_DIR="$HOME/macos-setup"
DEFAULT_COMPUTER_OWNER="Kris"
DEFAULT_COMPUTER_NAME="Silicon"
DEFAULT_TIME_ZONE="America/New_York"
SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::' | xargs) # Trim whitespace

# Constants
readonly SUDO_KEEPALIVE_TIMEOUT=300 # Seconds (5 minutes)
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly $GITHUB_USERNAME="khaosx"

# Functions

get_user_input() {
    local prompt="$1"
    local default_value="$2"
    local input

    printf "$prompt (Leave blank for default: %s)\n" "$default_value" > /dev/tty  # Write prompt to /dev/tty
    read -r input < /dev/tty # Read input from /dev/tty
    echo "${input:-$default_value}"  # Return the input or default
}

is_mac_app_store_signed_in() {
  printf "Have you signed in to the Mac App Store? (y/n)\n"  # Prompt the user
  read -r reply                                          # Read the user's input

  if [[ "$reply" =~ ^[Yy]$ ]]; then                     # Check if the input is "y" or "Y"
    return 0                                            # Return 0 (success) if signed in
  else
    return 1                                            # Return 1 (failure) if not signed in
  fi
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
  else
    echo "Homebrew is already installed."
  fi
}

install_brewfile() {
    if [[ -n "$HOMEBREW_BUNDLE_FILE" ]]; then
      printf "\nInstalling base loadout.\n"
      brew bundle
      brew cleanup
    else
      printf "\nNo brewfile found, please install applications manually.\n"
      printf "To avoid this step:\n"
      printf "Generate with \"brew bundle --file=$HOME/.Brewfile\"\n"
      printf "Run command \'export HOMEBREW_BUNDLE_FILE=\"$HOME/.Brewfile\"\n"
    fi
}

install_ansible_components() {
    printf "\nInstalling Ansible collections.\n"
    ansible-galaxy collection install community.general
}

install_dotfiles() {
    printf "\nInstalling and linking dotfiles.\n"
    chezmoi init --apply https://github.com/$GITHUB_USERNAME/dotfiles.git
}

# Main script logic
clear

printf "*************************************************************************\\n"
printf "*******                                                           *******\\n"
printf "*******                 Post Install MacOS Config                 *******\\n"
printf "*******                                                           *******\\n"
printf "*************************************************************************\\n\\n"

[[ $(uname -s) != "Darwin" ]] && { echo "This script only supports macOS. Exiting."; exit 1; }
printf "OS Verified. You may be prompted to enter your password for sudo\n\n"

# Authenticate via sudo and update existing `sudo` time stamp until finished
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

printf "\nNow, let's get some info about your setup.\n\n"

COMPUTER_NAME=$(get_user_input "Enter a name for your Mac" "$DEFAULT_COMPUTER_NAME")
COMPUTER_OWNER=$(get_user_input "Who is the primary user of this system?" "$DEFAULT_COMPUTER_OWNER")
printf "NOTE: To view all zones, exit and run \`sudo systemsetup -listtimezones\`\n"
TIME_ZONE=$(get_user_input "Enter your time zone" "$DEFAULT_TIME_ZONE")

if is_mac_app_store_signed_in; then
  echo "Mac App Store sign-in confirmed. Continuing...\n\n"
else
  echo "Mac App Store sign-in check failed. Exiting."
  exit 1
fi

COMPUTER_DESCRIPTION="$COMPUTER_OWNER's $SYSDESC"
HOST_NAME=$(echo "$COMPUTER_NAME" | tr '[:upper:]' '[:lower:]')

printf "Here's what we've got so far:\\n"
printf "Bootstrap Script:       ==> $BOOTSTRAP_REPO_URL\\n"
printf "Bootstrap Directory:    ==> $BOOTSTRAP_DIR\\n"
printf "Computer Name:          ==> $COMPUTER_NAME\\n"
printf "Computer Description:   ==> $COMPUTER_DESCRIPTION\\n"
printf "Host Name:              ==> $HOST_NAME\\n"
printf "Time Zone:              ==> $TIME_ZONE\\n"
printf "App Store Login:        ==> CONFIRMED\\n\\n"
printf "Continue? (y/n)\n" > /dev/tty  # Prompt to /dev/tty
read -r CONFIRM < /dev/tty           # Read from /dev/tty

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
eval "$(/opt/homebrew/bin/brew shellenv)" # Activate in current shell
brew analytics off
brew install chezmoi
brew doctor

install_dotfiles

install_brewfile

install_ansible_components

printf  "\n**********************************************************************\\n"
printf  "**********************************************************************\\n"
printf  "****                                                              ****\\n"
printf  "****            MacOS post-install script complete!               ****\\n"
printf  "****                Please restart your computer.                 ****\\n"
printf  "****                                                              ****\\n"
printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
exit 0

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
BOOTSTRAP_REPO_URL="https://github.com/khaosx/bootstrap-macos.git"
BOOTSTRAP_DIR=$HOME/macos-setup
DEFAULT_COMPUTER_OWNER="Kris"
DEFAULT_COMPUTER_NAME="Silicon"
DEFAULT_TIME_ZONE="America/New_York"
SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::')

# Let's get started
clear
printf "*************************************************************************\\n"
printf "*******                                                           *******\\n"
printf "*******                 Post Install MacOS Config                 *******\\n"
printf "*******                                                           *******\\n"
printf "*************************************************************************\\n\\n"

printf "Verifying MacOS is the operating system...\\n"
if [[ $(uname -s) != "Darwin" ]]; then  # Use [[ ]] for string comparison in Zsh
  printf "This script only supports MacOS. Exiting.\\n"
  exit 1
else
  printf "OS Verified. You may be prompted to enter your password for sudo\\n\\n"
fi

# Authenticate via sudo and update existing `sudo` time stamp until finished
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

printf "\\nNow, let's get some info about your setup.\\n\\n"
printf "\\nEnter a name for your Mac. (Leave blank for default: %s)\n" "$DEFAULT_COMPUTER_NAME"
read -r COMPUTER_NAME
printf "\\nWho is the primary user of this system? (Leave blank for default: %s)\n" "$DEFAULT_COMPUTER_OWNER"
read -r COMPUTER_OWNER
printf "\\nEnter your time zone.  (Leave blank for default: $DEFAULT_TIME_ZONE)\\n"
printf "NOTE: To view all zones, run \`sudo systemsetup -listtimezones\`\\n"
read -r TIME_ZONE
printf "\\n"
read -r "REPLY?Please sign in to the Mac App Store. Press Enter when done."
COMPUTER_NAME="${COMPUTER_NAME:-$DEFAULT_COMPUTER_NAME}"
COMPUTER_OWNER="${COMPUTER_OWNER:-$DEFAULT_COMPUTER_OWNER}"
COMPUTER_DESCRIPTION="$COMPUTER_OWNER's $SYSDESC"         # cat into default description
TIME_ZONE="${TIME_ZONE:-$DEFAULT_TIME_ZONE}"
HOST_NAME=$(echo ${COMPUTER_NAME} | tr '[:upper:]' '[:lower:]')

clear
printf "Looks good. Here's what we've got so far.\\n"
printf "Bootstrap Script:       ==> $BOOTSTRAP_REPO_URL\\n"
printf "Bootstrap Directory:    ==> $BOOTSTRAP_DIR\\n"
printf "Computer Name:          ==> $COMPUTER_NAME\\n"
printf "Computer Description:   ==> $COMPUTER_DESCRIPTION\\n"
printf "Host Name:              ==> $HOST_NAME\\n"
printf "Time Zone:              ==> $TIME_ZONE\\n"
printf "Continue? (y/n)\\n"
read CONFIRM
echo
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  printf "Exiting per user choice\\n"
  exit 1
fi

printf "Applying basic system info\\n"

printf "Setting system label and name\\n"
sudo scutil --set ComputerName $COMPUTER_NAME
sudo scutil --set HostName $HOST_NAME
sudo scutil --set LocalHostName $HOST_NAME
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $HOST_NAME
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server ServerDescription -string "$COMPUTER_DESCRIPTION"

printf "Setting system time zone\\n"
sudo systemsetup -settimezone "$TIME_ZONE" > /dev/null

# Enabling location services
sudo /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -int 1
sudo /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$UUID LocationServicesEnabled -int 1

# Configure automatic timezone
sudo /usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool YES
sudo /usr/bin/defaults write /private/var/db/timed/Library/Preferences/com.apple.timed.plist TMAutomaticTimeOnlyEnabled -bool YES
sudo /usr/bin/defaults write /private/var/db/timed/Library/Preferences/com.apple.timed.plist TMAutomaticTimeZoneEnabled -bool YES
sudo /usr/sbin/systemsetup -setusingnetworktime on

printf "Checking Command Line Tools for Xcode\\n"
xcode-select -p &> /dev/null  # Tries to print the path
if [ $? -ne 0 ]; then
  printf "Command Line Tools for Xcode not found. Installing from softwareupdate.\\n"
# This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
  PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
  softwareupdate -i "$PROD" --verbose;
else
  printf "Command Line Tools for Xcode have been installed.\\n"
fi

printf "Installing HomeBrew\\n"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> /$HOME/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /$HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew analytics off
brew doctor

printf "Installing base loadout\\n"
brew install ansible ansible-lint git wget jq mas dockutil
brew install --cask 1password vscodium

ansible-galaxy collection install community.general

printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
printf  "****                                                              ****\\n"
printf  "****            MacOS post-install script complete!               ****\\n"
printf  "****                Please restart your computer.                 ****\\n"
printf  "****                                                              ****\\n"
printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
exit 0

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

# Make sure we're on a Mac before continuing
if [ $(uname) != "Darwin" ]; then
  printf "Oops, it looks like you're using a non-MacOS system. This script only supports MacOS. Exiting..."
  exit 1
fi

# Establish some ground rules
export BOOTSTRAP_REPO_URL="https://github.com/khaosx/bootstrap-macos.git"
export BOOTSTRAP_DIR=$HOME/macos-setup
export DEFAULT_COMPUTER_OWNER="Kris"
export DEFAULT_COMPUTER_NAME="Silicon"
export DEFAULT_TIME_ZONE="America/New_York"

SYSDESC=$(system_profiler SPHardwareDataType | grep -o "Model Name:.*" | sed 's:.*Model Name\: ::')

# Authenticate via sudo and update existing `sudo` time stamp until finished
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Let's get started
clear
printf "*************************************************************************\\n"
printf "*******                                                           *******\\n"
printf "*******                 Post Install MacOS Config                 *******\\n"
printf "*******                                                           *******\\n"
printf "*************************************************************************\\n\\n"

printf "Before we get started, let's get some info about your setup.\\n"

# Get system name

printf "Enter a name for your Mac. (Leave blank for default: $DEFAULT_COMPUTER_NAME)\\n"
read COMPUTER_NAME
export COMPUTER_NAME=${COMPUTER_NAME:-$DEFAULT_COMPUTER_NAME}

# Generate system description
printf "Who is the primary user of this system? (Leave blank for default: $DEFAULT_COMPUTER_OWNER)\\n"
read COMPUTER_OWNER
export COMPUTER_OWNER=${COMPUTER_OWNER:-$DEFAULT_COMPUTER_OWNER}
strFinalDescription="$COMPUTER_OWNER's $SYSDESC"
export COMPUTER_DESCRIPTION=$strFinalDescription

# Get time zone
export DEFAULT_TIME_ZONE="America/New_York"
printf "Enter your desired time zone.\\n"
printf "To view available options run \`sudo systemsetup -listtimezones\`\\n"
printf "(Leave blank for default: $DEFAULT_TIME_ZONE)\\n"
read TIME_ZONE
export TIME_ZONE=${TIME_ZONE:-$DEFAULT_TIME_ZONE}

printf "Have you signed in to the Mac App Store? (y/n)\\n"
read flagAppStoreSignedIn
echo
if [[ ! "$flagAppStoreSignedIn" =~ ^[Yy]$ ]]; then
  printf "Please sign into the Mac App Store\\n"
  exit 1
fi

# I want all hostnames to be the lowercase version of the computer name
HOST_NAME=$(echo ${COMPUTER_NAME} | tr '[:upper:]' '[:lower:]')
export HOST_NAME=${HOST_NAME}

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

printf "Installing HomeBrew\\n"
/bin/bash -c "$(NONINTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew analytics off
brew doctor

printf "Installing Ansible"
brew install ansible ansible-lint

printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
printf  "****                                                              ****\\n"
printf  "****            MacOS post-install script complete!               ****\\n"
printf  "****                Please restart your computer.                 ****\\n"
printf  "****                                                              ****\\n"
printf  "**********************************************************************\\n"
printf  "**********************************************************************\\n"
exit 0
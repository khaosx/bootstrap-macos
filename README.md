# bootstrap_macos.sh - macOS Post-Install Configuration  

## Description:
This script automates common post-installation tasks for macOS, including
configuring system settings, installing command-line tools, and setting up
essential applications. It is intended to streamline the setup process
after a fresh macOS installation.  

## Usage: 
`./bootstrap_macos.sh`  

## Configuration:
Default values and settings are defined in a separate configuration file `config.cfg`  

## Dependencies:
* macOS (Darwin kernel)
* An active internet connection
* Xcode Command Line Tools (automatically installed if not present)
* Homebrew (automatically installed)
* Homebrew bundle containing all dependencies for brew, mas, cask, etc (Optional, but recommended)
   * Generate with "brew bundle --file=$HOME/.Brewfile"
   * Set with command export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"  

## Notes:
* This script requires administrator privileges (sudo) to perform certain actions.
* A system restart is recommended after the script completes.
* This script draws inspiration from and adapts concepts from other bootstrap scripts, including those available on GitHub. Attribution for specific components is provided within the script where applicable.  

## License:
[MIT License](https://github.com/khaosx/bootstrap-macos/tree/main?tab=MIT-1-ov-file#)

## Install with a step and a one-liner:

Create config.cfg with the following variables (replace default values with your own):
```Bash
DEFAULT_COMPUTER_OWNER="Rick Sanchez"
DEFAULT_COMPUTER_NAME="Citadel"
DEFAULT_TIME_ZONE="America/New_York"
GITHUB_USERNAME="JerrySmith"
BOOTSTRAP_DIR="$HOME/macos-setup"
HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"  # Update this path if your Brewfile is elsewhere
```

and then...

```
curl --remote-name https://raw.githubusercontent.com/khaosx/bootstrap-macos/refs/heads/main/config.cfg && curl --remote-name https://raw.githubusercontent.com/khaosx/bootstrap-macos/refs/heads/main/bootstrap_macos.sh && sh bootstrap_macos.sh 2>&1 | tee ~/install.log
```

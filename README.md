# bootstrap_macos.sh - macOS Post-Installation Configuration

## Author: Kristopher Newman
## Date: 2025-02-06

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
* * Generate with "brew bundle --file=$HOME/.Brewfile"
* * Set with command export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"  

## Notes:
* This script requires administrator privileges (sudo) to perform certain actions.
* A system restart is recommended after the script completes.
* This script draws inspiration from and adapts concepts from other bootstrap scripts, including those available on GitHub. Attribution for specific components is provided within the script where applicable.  

## License:
MIT License

## Install with one-liner:

```
curl --remote-name https://raw.githubusercontent.com/khaosx/bootstrap-macos/refs/heads/main/bootstrap_macos.sh && sh bootstrap_macos.sh 2>&1 | tee ~/install.log
```

#!/bin/bash

#------------------------------------------------
#-KickStart--------------------------------------
#-(c) Joshua Brest-------------------------------
#-A quick script to provision my computers.------
#------------------------------------------------

# Enter the script into sudo mode
sudo -v

# Turn on non interactive mode
export NONINTERACTIVE=true

# Redirect srderr to stdout
exec 2>&1

# Log files
LOG_FILE="./setup.log"

# System type (Apple Silicon or Intel)
SYSTEM_TYPE=$(uname -m)

# Temp directory
TMP_RD=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
mkdir -p "$TMPDIR/appinstaller.$TMP_RD"
TMP="$TMPDIR/appinstaller.$TMP_RD/"

# Clear the log file
echo "" > "$LOG_FILE"

# Log data
# $1: the data to log
# -- Returns --
# null
log()
{
    # Print the data
    printf "\033[0;1;32mLog\t| \033[0m$1\n"
    # Log the data
    echo "LOG   | $1" >> "$LOG_FILE"
}

# Log error
# $1: the error to log
# -- Returns --
# null
log_error()
{
    # Print the error
    printf "\033[0;1;31mError\t| \033[0m$1\n"
    # Log the error
    echo "ERROR | $1" >> "$LOG_FILE"
}

log "Log start at $(date)"


# Clear console
# null
# -- Returns --
# null
clear_console()
{
    # Clear the console
    clear
}

# Install xcode CLI tools
log "Installing Xcode CLI tools"
xcode-select --install >> "$LOG_FILE" || log_error "Xcode CLI failed install"

# Install brew
log "Installing brew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" || log "Brew failed install"
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
eval $(brew shellenv)

#----------------------------------#
#-------------UTILS----------------#
#----------------------------------#

# M1 or Intel String
# $1: M1 string
# $2: Intel string
# -- Returns --
# $return: the string
m1_or_intel()
{
    if [ "$SYSTEM_TYPE" = "arm64" ]; then
        return="$1"
    else
        return="$2"
    fi
}

# Downloads files into the temp directory
# $1: URL
# -- Returns --
# $success: true if the download was successful
# $return: the file path
download()
{
    # Random file name 32 characters long
    local file_name=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    # Download file path
    local temp_fs="$TMP/$file_name"

    # Create file
    touch "$temp_fs"

    # Download file
    curl -L "$1" -o "$temp_fs" --show-error --silent >> "$LOG_FILE" || {
        success=false
        return
    }
    echo "CURL: Downloaded $1 to $temp_fs." >> "$LOG_FILE"

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        success=true
    else
        success=false
    fi

    # Return the file path
    return="$temp_fs"
}

# Extracts and installs a .dmg file using drag and drop
# $1: the dmg path
# $2: the app name
# -- Returns --
# $success: true if the installation was successful
install_dmg_drag()
{
    # Create a random 32 character string on macOS
    local mount_rnd=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    local mount_path="$TMP/$mount_rnd"

    # Mount the dmg
    hdiutil attach "$1" -mountpoint "$mount_path" >> "$LOG_FILE" || {
        success=false
        return
    }

    # Get the app path
    local app_path=$(find "$mount_path" -name "$2" -type d)

    # If it is not found, return false
    if [ -z "$app_path" ]; then
        success=false
        return
    fi

    # Copy the app to the applications folder
    cp -r "$app_path" "/Applications/$2"

    # Unmount the dmg
    hdiutil detach "$mount_path" >> $LOG_FILE || {
        success=false
        return
    }

    # Return true
    success=true
}

# Dmg Drag Package Install
# $1: the package url
# $2: the app name
# -- Returns --
# $success: true if the installation was successful
dmg_drag_package_install()
{
    # Download the package
    download "$1"

    # Check if the download was successful
    if [ "$success" = false ]; then
        log_error "[DMG Drag Package] Download failed for $1"
        success=false
        return
    fi

    # Install the package
    install_dmg_drag "$return" "$2"

    # Check if the installation was successful
    if [ "$success" = false ]; then
        log_error "[DMG Drag Package] Installation failed for $1"
        success=false
        return
    fi

    # Clear the temp directory
    rm "$return" >> /dev/null

    # Return true
    success=true
}

# Zip Package Install
# $1: the package url
# $2: the app name
# -- Returns --
# $success: true if the installation was successful
zip_package_install()
{
    # Download the package
    download "$1"

    # Check if the download was successful
    if [ "$success" = false ]; then
        log_error "[Zip Package] Download failed for $2"
        success=false
        rm "$return" >> /dev/null
        return
    fi

    # Extract only the app
    unzip "$return" "$2/*" -d "$return.app" >> "$LOG_FILE" || {
        log_error "[Zip Package] Extraction failed for $2"
        success=false
        rm "$return" >> /dev/null
        return
    }

    # Get the app path
    local app_path=$(find "$return.app" -name "$2" -type d)

    # If it is not found, return false
    if [ -z "$app_path" ]; then
        log_error "[Zip Package] Extracted target not found for $2"
        success=false
        rm "$return" >> /dev/null
        rm -rf "$return.app" >> /dev/null
        return
    fi

    # Copy the app to the applications folder
    cp -r "$app_path" "/Applications/$2"

    # Clear the temp directory
    rm "$return" >> /dev/null
    rm -rf "$return.app" >> /dev/null

    # Return true
    success=true
}
# Pkg Package Install
# $1: the package url
# -- Returns --
# $success: true if the installation was successful
pkg_package_install()
{
    # Download the package
    download "$1"

    # Check if the download was successful
    if [ "$success" = false ]; then
        log_error "[Pkg Package] Download failed for $1"
        success=false
        rm "$return" >> /dev/null
        return
    fi

    # Rename to .pkg
    mv "$return" "$return.pkg"

    # Install the package
    sudo installer -pkg "$return.pkg" -target / >> "$LOG_FILE" || {
        log_error "[Pkg Package] Installation failed for $1"
        success=false
        rm "$return.pkg" >> /dev/null
        return
    }

    # Clear the temp directory
    rm "$return.zip" >> /dev/null

    # Return true
    success=true
}

# DMG packed PKG Package Install
# $1: the package url
# $2: the pkg name
# $3: the app name
# -- Returns --
# $success: true if the installation was successful
dmg_pkg_package_install()
{
    # Download the package
    download "$1"

    # Check if the download was successful
    if [ "$success" = false ]; then
        log_error "[DMG Pkg Package] Download failed for $1"
        success=false
        rm "$return" >> /dev/null
        return
    fi

    # Create a random 32 character string on macOS
    local mount_rnd=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    local mount_path="$TMP/$mount_rnd"

    # Mount the dmg
    hdiutil attach "$return" -mountpoint "$mount_path" >> "$LOG_FILE" || {
        log_error "[DMG Pkg Package] Mount failed for $1"
        success=false
        rm "$return" >> /dev/null
        return
    }

    # Get the app path
    local app_path=$(find "$mount_path" -name "$2" -type f)

    # If it is not found, return false
    if [ -z "$app_path" ]; then
        log_error "[DMG Pkg Package] Extracted target not found for $1"
        success=false
        rm "$return" >> /dev/null
        return
    fi

    # Install the package
    sudo installer -pkg "$app_path" -target / >> "$LOG_FILE" || {
        log_error "[DMG Pkg Package] Installation failed for $1"
        success=false
        rm "$return" >> /dev/null
        return
    }

    # Unmount the dmg
    hdiutil detach "$mount_path" >> $LOG_FILE || {
        log_error "[DMG Pkg Package] Unmount failed for $1"
        rm "$return" >> /dev/null
        success=false
        return
    }

    # Clear the temp directory
    rm "$return" >> /dev/null

    # Return true
    success=true
}


# Install Mac App Store apps
# $1: the app id
# $2: the app name
# -- Returns --
# $success: true if the installation was successful
mas_install()
{
    # Install the app
    mas install "$1" >> "$LOG_FILE" || {
        log_error "[Mac App Store] Installation failed for $2"
        success=false
        return
    }

    # Return true
    success=true
}

#-----------------#
#------APPS-------#
#-----------------#

# Raycasts
log "Installing Raycasts"
dmg_drag_package_install "https://api.raycast.app/v2/download" "Raycast.app"
# Arc browser
log "Installing Arc browser"
dmg_drag_package_install "https://releases.arc.net/release/Arc-latest.dmg" "Arc.app"
# iTerm2
log "Installing iTerm2"
zip_package_install "https://iterm2.com/downloads/stable/latest" "iTerm.app"
# Visual Studio Code
log "Installing Visual Studio Code"
zip_package_install "https://go.microsoft.com/fwlink/?LinkID=620882" "Visual Studio Code.app"
# Zoom.us
log "Installing Zoom.us"
pkg_package_install "https://zoom.us/client/latest/Zoom.pkg"
# NordVPN
log "Installing NordVPN"
pkg_package_install "https://downloads.nordcdn.com/apps/macos/generic/NordVPN-OpenVPN/latest/NordVPN.pkg"
# Steam
log "Installing Steam"
dmg_drag_package_install "https://cdn.cloudflare.steamstatic.com/client/installer/steam.dmg" "Steam.app"
# Insomnia REST Client
log "Installing Insomnia REST Client"
dmg_drag_package_install "https://updates.insomnia.rest/downloads/mac/latest" "Insomnia.app"
# Burp Suite Community Edition
log "Installing Burp Suite Community Edition"
m1_or_intel "https://portswigger.net/burp/releases/startdownload?product=community&version=2023.1.2&type=macosarm64" "https://portswigger.net/burp/releases/startdownload?product=community&version=2023.1.2&type=macosx"
dmg_drag_package_install "$return" "Burp Suite Community Edition.app"
# Docker Desktop Manager
log "Installing Docker Desktop Manager"
m1_or_intel "https://desktop.docker.com/mac/stable/amd64/Docker.dmg" "https://desktop.docker.com/mac/stable/arm64/Docker.dmg"
dmg_drag_package_install "$return" "Docker.app"
# Discord
log "Installing Discord"
dmg_drag_package_install "https://discord.com/api/download?platform=osx&format=dmg" "Discord.app"
# WhatsApp
log "Installing WhatsApp"
dmg_drag_package_install "https://web.whatsapp.com/desktop/mac/files/WhatsApp.dmg" "WhatsApp.app"
# LanguageTool
log "Installing LanguageTool"
dmg_drag_package_install "https://languagetool.org/download/mac-app/LanguageToolDesktop-latest.dmg" "LanguageTool for Desktop.app"
# Bitwarden
log "Installing Bitwarden"
dmg_drag_package_install "https://vault.bitwarden.com/download/?app=desktop&platform=macos" "Bitwarden.app"
# Rocket Emoji
log "Installing Rocket Emoji"
dmg_drag_package_install "https://macrelease.matthewpalmer.net/Rocket.dmg" "Rocket.app"
# GPG Suite
log "Installing GPG Suite"
dmg_pkg_package_install "https://releases.gpgtools.org/GPG_Suite-2022.2.dmg" "Install.pkg" "GPG Suite"
# Texifier
log "Installing Texifier"
dmg_drag_package_install "https://download.texifier.com/apps/osx/updates/Texifier_1_9_19__741__c66201c.dmg" "Texifier.app"


#-------------------#
#-----CLI-APPS------#
#-------------------#
log "Installing CLI apps"

# Node.js
log "Installing Node.js"
brew install node
# Yarn
log "Installing Yarn"
brew install yarn
# Rust
log "Installing Rust"
brew install rust
# Mac App Store CLI
log "Installing Mac App Store CLI"
brew install mas
# Github CLI
log "Installing Github CLI"
brew install gh

#------------------------#
#-----APP-STORE-APPS-----#
#------------------------#
log "App Store apps. Please login to the App Store if you haven't already."

# # Wait for the user to login
read -p "Press enter to continue"

# Ulysses | Writing App: id1225570693
log "Installing Ulysses"
mas_install "1225570693" "Ulysses"
# Dropover - Easier Drag & Drop: id1355679052
log "Installing Dropover - Easier Drag & Drop"
mas_install "1355679052" "Dropover - Easier Drag & Drop"
# Magnet: id441258766
log "Installing Magnet"
mas_install "441258766" "Magnet"
# Balance: Mindful time tracking: id1637311725
log "Installing Balance: Mindful time tracking"
mas_install "1637311725" "Balance: Mindful time tracking"



#-----------------#
#-----CLEANUP-----#
#-----------------#

# Clear the temp directory
rm -rf "$TMP"

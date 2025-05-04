#!/bin/bash

echo "DayZ Linux Server Installer"
echo "================================"
echo

# --- !!! CONFIGURATION - EDIT THESE VALUES !!! ---

# Set your Steam username
STEAM_USER=""

# Set your Steam password (!!! SECURITY RISK - SEE WARNING BELOW !!!)
STEAM_PASS=""

# --- !!! END CONFIGURATION !!! ---

# Set basic variables
WORKSPACE="$(pwd)"
STEAM_APP_ID="223350"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_TAR="${WORKSPACE}/steamcmd_linux.tar.gz"
STEAMCMD_DIR="${WORKSPACE}/steamcmd"

echo
echo "========================== SECURITY WARNING =========================="
echo "  Storing your Steam password directly in this script"
echo "  is a SIGNIFICANT SECURITY RISK. Anyone with access to this file"
echo "  will have your Steam credentials."
echo
echo "  RECOMMENDATIONS:"
echo "  1. Use a DEDICATED Steam account solely for managing servers."
echo "  2. Secure this file and the computer it's on carefully."
echo "  3. Be aware of Steam Guard (2FA) requirements (see below)."
echo "======================================================================"
echo

# Try to get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi

# Try to get public IP
PUBLIC_IP="$LOCAL_IP"
PUBLIC_IP_TEMP=$(curl -s https://api.ipify.org)
if [ ! -z "$PUBLIC_IP_TEMP" ]; then
    PUBLIC_IP="$PUBLIC_IP_TEMP"
fi

echo "Workspace: $WORKSPACE"
echo "Steam App ID: $STEAM_APP_ID"
echo "Steam Username: $STEAM_USER"
echo "Local IP: $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
echo

# Check and install required dependencies
echo "Checking for required dependencies..."
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu system"
    echo "Installing required dependencies..."
    apt-get update -y
    apt-get install -y lib32gcc-s1 || apt-get install -y lib32gcc1
    apt-get install -y lib32stdc++6 libc6-i386
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    echo "Detected CentOS/RHEL system"
    echo "Installing required dependencies..."
    yum install -y glibc.i686 libstdc++.i686
else
    echo "Warning: Could not determine Linux distribution for automatic dependency installation"
    echo "You may need to manually install 32-bit libraries required for SteamCMD"
fi
echo

# Create steamcmd directory
echo "Creating SteamCMD directory..."
mkdir -p "$STEAMCMD_DIR"
echo

# Download SteamCMD
echo "Downloading SteamCMD..."
curl -s -o "$STEAMCMD_TAR" "$STEAMCMD_URL"
echo "Download complete."
echo

# Extract SteamCMD
echo "Extracting SteamCMD..."
tar -xzf "$STEAMCMD_TAR" -C "$STEAMCMD_DIR"
echo "Extraction complete."
echo

# Delete TAR file
if [ -f "$STEAMCMD_TAR" ]; then
    rm "$STEAMCMD_TAR"
fi

# Find steamcmd.sh
if [ -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
    STEAMCMD_EXE="$STEAMCMD_DIR/steamcmd.sh"
elif [ -f "$STEAMCMD_DIR/Steam/steamcmd.sh" ]; then
    STEAMCMD_EXE="$STEAMCMD_DIR/Steam/steamcmd.sh"
else
    echo "ERROR: Could not find steamcmd.sh"
    exit 1
fi

# Make steamcmd.sh executable
chmod +x "$STEAMCMD_EXE"

# Initialize SteamCMD first
echo "Initializing SteamCMD..."
"$STEAMCMD_EXE" +quit || {
    echo "ERROR: Failed to initialize SteamCMD"
    echo "This may be due to missing dependencies"
    exit 1
}

echo
echo "========================== IMPORTANT NOTE =========================="
echo "If Steam Guard (2-Factor Authentication) is enabled for the account"
echo "'$STEAM_USER', SteamCMD will likely pause and prompt you here"
echo "to enter the current code from your authenticator app or email."
echo "You MUST type the code in this console window and press Enter."
echo "This script CANNOT automate the 2FA process."
echo "===================================================================="
echo

# Run SteamCMD to install server with user credentials
echo "Installing server..."
"$STEAMCMD_EXE" +force_install_dir "$WORKSPACE" +login $STEAM_USER $STEAM_PASS +app_update $STEAM_APP_ID validate +quit

# Check if installation was successful
if [ $? -ne 0 ]; then
    echo "ERROR: Server installation failed"
    echo "Check the output above. Common issues include:"
    echo "  - Incorrect username/password"
    echo "  - Steam Guard code required but not entered or entered incorrectly"
    echo "  - Network/Steam connectivity problems"
    echo "  - Disk space issues"
    exit 1
fi

echo
echo "Installation complete."
echo "Server has been installed to: $WORKSPACE"
echo "You can now start your server through the MCSManager panel."

echo "Script made by @Wil3on"
exit 0

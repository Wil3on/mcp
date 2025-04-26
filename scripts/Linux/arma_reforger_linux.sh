#!/bin/bash

echo "Arma Reforger Linux Server Installer"
echo "================================"
echo

# Set basic variables
WORKSPACE="$(pwd)"
STEAM_APP_ID="1874900"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_TAR="${WORKSPACE}/steamcmd_linux.tar.gz"
STEAMCMD_DIR="${WORKSPACE}/steamcmd"

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
echo "Local IP: $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
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

# Run SteamCMD to install server
echo "Installing server..."
"$STEAMCMD_EXE" +login anonymous +force_install_dir "$WORKSPACE" +app_update $STEAM_APP_ID validate +quit

# Check if config.json already exists
if [ -f "$WORKSPACE/config.json" ]; then
    echo "Config file already exists. Preserving existing configuration."
else
    # Create config.json if it doesn't exist
    echo "Creating config.json..."
    cat > "$WORKSPACE/config.json" << EOF
{
	"bindAddress": "$LOCAL_IP",
	"bindPort": 2001,
	"publicAddress": "$PUBLIC_IP",
	"publicPort": 2001,
	"a2s": {
		"address": "$LOCAL_IP",
		"port": 17777
	},
	"rcon": {
		"address": "$LOCAL_IP",
		"port": 19999,
		"password": "MyPassRcon",
		"permission": "monitor",
		"blacklist": [],
		"whitelist": []
	},
	"game": {
		"name":"Wil3on MCS Server",
		"password": "",
		"passwordAdmin": "MyPass",
		"admins" : [
			"66561199094966237"
		],
		"scenarioId": "{ECC61978EDCC2B5A}Missions/23_Campaign.conf",
		"maxPlayers": 128,
		"visible": true,
		"crossPlatform": true,
		"supportedPlatforms": [
			"PLATFORM_PC",
			"PLATFORM_XBL"
		],
		"gameProperties": {
			"serverMaxViewDistance": 2500,
			"serverMinGrassDistance": 50,
			"networkViewDistance": 1000,
			"disableThirdPerson": true,
			"fastValidation": true,
			"battlEye": true,
			"VONDisableUI": false,
			"VONDisableDirectSpeechUI": false,
			"missionHeader": {
				"m_iPlayerCount": 40,
				"m_eEditableGameFlags": 6,
				"m_eDefaultGameFlags": 6,
				"other": "values"
			}
		},
		"mods": [
{
  "modId": "5AAAC70D754245DD",
  "name": "Server Admin Tools",
  "version": ""
}
		]
	},
    "operating": {
        "playerSaveTime": 420,
        "slotReservationTimeout": 60,
        "disableServerShutdown": false,
        "lobbyPlayerSynchronise": true,
        "joinQueue": {
            "maxSize": 50
        },
        "disableNavmeshStreaming": []
    }
}
EOF
    echo "Config file created."
fi

echo
echo "Installation complete."
echo "Server has been installed to: $WORKSPACE"
echo "You can now start your server through the MCSManager panel."

echo "Script made by @Wil3on"
exit 0

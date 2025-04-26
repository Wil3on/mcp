@echo off
setlocal enabledelayedexpansion

echo Arma Reforger Windows Server Installer
echo ================================
echo.

:: Set basic variables
set "WORKSPACE=%CD%"
set "STEAM_APP_ID=1874900"
set "STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
set "STEAMCMD_ZIP=%WORKSPACE%\steamcmd.zip"
set "STEAMCMD_DIR=%WORKSPACE%\steamcmd"

:: Try to get local IP
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "IPv4"') do (
    set "LOCAL_IP=%%i"
    set "LOCAL_IP=!LOCAL_IP:~1!"
    goto :ip_found
)
:ip_found

:: Try to get public IP
set "PUBLIC_IP=%LOCAL_IP%"
powershell -Command "(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content" > "%TEMP%\public_ip.txt"
set /p PUBLIC_IP_TEMP=<"%TEMP%\public_ip.txt"
if not "%PUBLIC_IP_TEMP%"=="" set "PUBLIC_IP=%PUBLIC_IP_TEMP%"
del "%TEMP%\public_ip.txt" 2>nul

echo Workspace: %WORKSPACE%
echo Steam App ID: %STEAM_APP_ID%
echo Local IP: %LOCAL_IP%
echo Public IP: %PUBLIC_IP%
echo.

:: Create steamcmd directory
echo Creating SteamCMD directory...
if not exist "%STEAMCMD_DIR%" mkdir "%STEAMCMD_DIR%"
echo.

:: Download SteamCMD
echo Downloading SteamCMD...
powershell -Command "Invoke-WebRequest -Uri '%STEAMCMD_URL%' -OutFile '%STEAMCMD_ZIP%' -UseBasicParsing"
echo Download complete.
echo.

:: Extract SteamCMD
echo Extracting SteamCMD...
powershell -Command "Expand-Archive -Path '%STEAMCMD_ZIP%' -DestinationPath '%STEAMCMD_DIR%' -Force"
echo Extraction complete.
echo.

:: Delete ZIP file
if exist "%STEAMCMD_ZIP%" del "%STEAMCMD_ZIP%"

:: Find steamcmd.exe
if exist "%STEAMCMD_DIR%\steamcmd.exe" (
    set "STEAMCMD_EXE=%STEAMCMD_DIR%\steamcmd.exe"
) else if exist "%STEAMCMD_DIR%\Steam\steamcmd.exe" (
    set "STEAMCMD_EXE=%STEAMCMD_DIR%\Steam\steamcmd.exe"
) else (
    echo ERROR: Could not find steamcmd.exe
    exit /b 1
)

:: Run SteamCMD to install server
echo Installing server...
"%STEAMCMD_EXE%" +login anonymous +force_install_dir "%WORKSPACE%" +app_update %STEAM_APP_ID% validate +quit

:: Check if config.json already exists
if exist "%WORKSPACE%\config.json" (
    echo Config file already exists. Preserving existing configuration.
) else (
    :: Create config.json if it doesn't exist
    echo Creating config.json...
    (
    echo {
    echo 	"bindAddress": "%LOCAL_IP%",
    echo 	"bindPort": 2001,
    echo 	"publicAddress": "%PUBLIC_IP%",
    echo 	"publicPort": 2001,
    echo 	"a2s": {
    echo 		"address": "%LOCAL_IP%",
    echo 		"port": 17777
    echo 	},
    echo 	"rcon": {
    echo 		"address": "%LOCAL_IP%",
    echo 		"port": 19999,
    echo 		"password": "MyPassRcon",
    echo 		"permission": "monitor",
    echo 		"blacklist": [],
    echo 		"whitelist": []
    echo 	},
    echo 	"game": {
    echo 		"name":"Wil3on MCS Server",
    echo 		"password": "",
    echo 		"passwordAdmin": "MyPass",
    echo 		"admins" : [
    echo 			"66561199094966237"
    echo 		],
    echo 		"scenarioId": "{ECC61978EDCC2B5A}Missions/23_Campaign.conf",
    echo 		"maxPlayers": 128,
    echo 		"visible": true,
    echo 		"crossPlatform": true,
    echo 		"supportedPlatforms": [
    echo 			"PLATFORM_PC",
    echo 			"PLATFORM_XBL"
    echo 		],
    echo 		"gameProperties": {
    echo 			"serverMaxViewDistance": 2500,
    echo 			"serverMinGrassDistance": 50,
    echo 			"networkViewDistance": 1000,
    echo 			"disableThirdPerson": true,
    echo 			"fastValidation": true,
    echo 			"battlEye": true,
    echo 			"VONDisableUI": false,
    echo 			"VONDisableDirectSpeechUI": false,
    echo 			"missionHeader": {
    echo 				"m_iPlayerCount": 40,
    echo 				"m_eEditableGameFlags": 6,
    echo 				"m_eDefaultGameFlags": 6,
    echo 				"other": "values"
    echo 			}
    echo 		},
    echo 		"mods": [
    echo {
    echo   "modId": "5AAAC70D754245DD",
    echo   "name": "Server Admin Tools",
    echo   "version": ""
    echo }
    echo 		]
    echo 	},
    echo     "operating": {
    echo         "playerSaveTime": 420,
    echo         "slotReservationTimeout": 60,
    echo         "disableServerShutdown": false,
    echo         "lobbyPlayerSynchronise": true,
    echo         "joinQueue": {
    echo             "maxSize": 50
    echo         },
    echo         "disableNavmeshStreaming": []
    echo     }
    echo }
    ) > "%WORKSPACE%\config.json"
    echo Config file created.
)

echo.
echo Installation complete.
echo Server has been installed to: %WORKSPACE%
echo You can now start your server through the MCSManager panel.

echo Script made by @Wil3on
exit /b 0
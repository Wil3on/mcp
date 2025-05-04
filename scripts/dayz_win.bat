@echo off
setlocal enabledelayedexpansion

echo DayZ Windows Server Installer (with User Login)
echo ================================================
echo.

:: --- !!! CONFIGURATION - EDIT THESE VALUES !!! ---

:: Set your Steam username
set STEAM_USER=

:: Set your Steam password (!!! SECURITY RISK - SEE WARNING BELOW !!!)
set STEAM_PASS=

:: --- !!! END CONFIGURATION !!! ---

:: Set basic variables
set "WORKSPACE=%CD%"
set "STEAM_APP_ID=223350"
set "STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
set "STEAMCMD_ZIP=%WORKSPACE%\steamcmd.zip"
set "STEAMCMD_DIR=%WORKSPACE%\steamcmd"

echo.
echo ========================== SECURITY WARNING ==========================
echo  Storing your Steam password directly in this script (%~f0)
echo  is a SIGNIFICANT SECURITY RISK. Anyone with access to this file
echo  will have your Steam credentials.
echo.
echo  RECOMMENDATIONS:
echo  1. Use a DEDICATED Steam account solely for managing servers.
echo  2. Secure this file and the computer it's on carefully.
echo  3. Be aware of Steam Guard (2FA) requirements (see below).
echo ======================================================================
echo.
echo Proceeding automatically...
echo.


:: Try to get local IP
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "IPv4"') do (
    set "LOCAL_IP=%%i"
    set "LOCAL_IP=!LOCAL_IP:~1!"
    goto :ip_found
)
:ip_found
if not defined LOCAL_IP set "LOCAL_IP=127.0.0.1" :: Fallback if IP not found

:: Try to get public IP
set "PUBLIC_IP=%LOCAL_IP%"
powershell -Command "(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content" > "%TEMP%\public_ip.txt" 2>nul
if exist "%TEMP%\public_ip.txt" (
    set /p PUBLIC_IP_TEMP=<"%TEMP%\public_ip.txt"
    if not "%PUBLIC_IP_TEMP%"=="" set "PUBLIC_IP=%PUBLIC_IP_TEMP%"
    del "%TEMP%\public_ip.txt" 2>nul
) else (
    echo WARNING: Could not retrieve public IP. Using local IP instead.
)


echo Workspace: %WORKSPACE%
echo Steam App ID: %STEAM_APP_ID%
echo Steam Username: %STEAM_USER%
echo Local IP: %LOCAL_IP%
echo Public IP: %PUBLIC_IP%
echo.

:: Create steamcmd directory if it doesn't exist
if not exist "%STEAMCMD_DIR%" (
    echo Creating SteamCMD directory...
    mkdir "%STEAMCMD_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create directory %STEAMCMD_DIR%. Check permissions.
        pause
        exit /b 1
    )
    echo.
)

:: Download SteamCMD if zip doesn't exist
if not exist "%STEAMCMD_ZIP%" (
    if not exist "%STEAMCMD_DIR%\steamcmd.exe" (
        echo Downloading SteamCMD...
        powershell -Command "try { Invoke-WebRequest -Uri '%STEAMCMD_URL%' -OutFile '%STEAMCMD_ZIP%' -UseBasicParsing } catch { Write-Error 'Failed to download SteamCMD. Check URL or network connection.'; exit 1 }"
        if errorlevel 1 (
             echo ERROR: Failed to download SteamCMD. Please check your internet connection or the URL.
             if exist "%STEAMCMD_ZIP%" del "%STEAMCMD_ZIP%"
             pause
             exit /b 1
        )
        echo Download complete.
        echo.
    )
)

:: Extract SteamCMD if needed
if exist "%STEAMCMD_ZIP%" (
    echo Extracting SteamCMD...
    powershell -Command "try { Expand-Archive -Path '%STEAMCMD_ZIP%' -DestinationPath '%STEAMCMD_DIR%' -Force } catch { Write-Error 'Failed to extract SteamCMD. ZIP might be corrupt or permissions issue.'; exit 1 }"
     if errorlevel 1 (
        echo ERROR: Failed to extract SteamCMD. The ZIP file might be corrupt or you lack permissions.
        pause
        exit /b 1
     )
    echo Extraction complete.
    echo.
    :: Delete ZIP file after successful extraction
    del "%STEAMCMD_ZIP%"
)


:: Find steamcmd.exe
if exist "%STEAMCMD_DIR%\steamcmd.exe" (
    set "STEAMCMD_EXE=%STEAMCMD_DIR%\steamcmd.exe"
) else (
    :: Attempt a deeper search in case it extracted into a subfolder (less common now)
    if exist "%STEAMCMD_DIR%\Steam\steamcmd.exe" (
        set "STEAMCMD_EXE=%STEAMCMD_DIR%\Steam\steamcmd.exe"
    ) else (
        echo ERROR: Could not find steamcmd.exe in %STEAMCMD_DIR%
        echo Please ensure SteamCMD downloaded and extracted correctly.
        pause
        exit /b 1
    )
)

:: Run SteamCMD to install/update server using provided credentials
echo.
echo Starting SteamCMD to install/update DayZ Server (App ID: %STEAM_APP_ID%)...
echo Using Username: %STEAM_USER%
echo Installing to: %WORKSPACE%
echo.
echo ========================== IMPORTANT NOTE ==========================
echo If Steam Guard (2-Factor Authentication) is enabled for the account
echo '%STEAM_USER%', SteamCMD will likely pause and prompt you here
echo to enter the current code from your authenticator app or email.
echo You MUST type the code in this console window and press Enter.
echo This script CANNOT automate the 2FA process.
echo ====================================================================
echo.

"%STEAMCMD_EXE%" +force_install_dir "%WORKSPACE%" +login %STEAM_USER% %STEAM_PASS% +app_update %STEAM_APP_ID% validate +quit

:: Check SteamCMD Exit Code
if errorlevel 1 (
    echo WARNING: SteamCMD exited with an error (code %errorlevel%).
    echo Check the output above. Common issues include:
    echo   - Incorrect username/password
    echo   - Steam Guard code required but not entered or entered incorrectly
    echo   - Network/Steam connectivity problems
    echo   - Disk space issues in %WORKSPACE%
    pause
    :: Decide if you want to exit here or continue with potentially incomplete files
    :: exit /b 1
) else (
    echo SteamCMD process completed successfully.
)
echo.

echo.
echo Installation/Update complete.
echo Server files should be located in: %WORKSPACE%
echo You can now start your server through the MCSManager panel or manually.

echo Script made by @Wil3on (modified for user login)
echo.
pause
exit /b 0

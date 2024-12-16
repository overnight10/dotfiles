@echo off

taskkill /f /im systemsettings.exe >nul 2>&1

start "" "C:\Windows\Resources\Themes\aero.theme" >nul 2>&1

timeout /t 2 /nobreak >nul

taskkill /f /im systemsettings.exe >nul 2>&1

exit
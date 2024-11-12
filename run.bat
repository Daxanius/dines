@cd /D "%~dp0"

call ./build.bat
@IF ERRORLEVEL 1 exit /B 1

@echo.
@echo Running...
mesen build/game.nes --nes.breakOnCrash=true --preferences.showFps=true --preferences.showLagCounter=true --preferences.showGameTimer=true --preferences.showTitleBarInfo=true --preferences.theme=Dark 
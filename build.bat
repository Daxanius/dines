cd /D "%~dp0"

rmdir /S /Q build
mkdir build

@echo.
@echo Compiling...
ca65 game.s -g -o build/game.o
@IF ERRORLEVEL 1 GOTO failure

@echo.
@echo Linking...
ld65 -o build/game.nes -C game.cfg build/game.o -m build/game.map.txt -Ln build/game.labels.txt --dbgfile build/game.dbg
@IF ERRORLEVEL 1 GOTO failure

@echo.
@echo Success!
exit /B 0

:failure
@echo.
@echo Build error!
exit /B 1
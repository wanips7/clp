@Echo off

SET "CurrentPath=%~dp0"

for %%I in ("%CurrentPath%\..") do set "AppDir=%%~fI"

start "Test" "%AppDir%\ClpExample.exe" -s
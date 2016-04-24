@ECHO OFF

# TODO: test windows install script
echo "WARNING: TOTALLY UNTESTED"
echo "remove return statement from file to try this script"
return

WHERE choco >nul 2>nul
if %ERRORLEVEL%==1 (
  call .choco/install.bat
) else (
  echo chocolaty is already installed
)

WHERE babun >nul 2>nul
if %ERRORLEVEL%==1 (
  call babun/install.bat
) else (
  echo babun is already installed
)

bash -c "sh ./bootstrap.sh"


@ECHO OFF

# TODO: test windows install script
echo "WARNING: TOTALLY UNTESTED"
echo "remove return statement from file to try this script"
return

WHERE choco >nul 2>nul
if %ERRORLEVEL%==1 (
  call builtins/choco/install.bat
) else (
  echo chocolaty is already installed
)

WHERE babun >nul 2>nul
if %ERRORLEVEL%==1 (
  call builtins/babun/install.bat
) else (
  echo babun is already installed
)

bash -c "sh ./install.sh"


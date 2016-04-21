@ECHO OFF

# TODO: WARNING: TOTALLY UNTESTED

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


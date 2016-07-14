@ECHO OFF

echo.
echo This script will install chocolatey and babun on your system,
echo MAKE SURE YOU ARE IN AN ELEVATED COMMAND PROMPT BEFORE PROCEEDING.
echo There if you do not want to use babun, you will need to manually install
echo cygwin or mysys and use .dotsys/installer.sh to install dotsys.
echo.

set install=y
set /p install="Would you like to proceed ? (y)es (n)o [y] : "
if /I NOT %install%==y (
 goto :eof
)

SET dspath=%~dp0
SET builtins=%dspath%builtins

:: Install chocolatey

WHERE choco >nul 2>nul

if %ERRORLEVEL%==1 (

  call %builtins%\choco\install.bat

) else (

  echo [ info ] chocolaty is already installed
)

:: Install babun

WHERE babun >nul 2>nul

if %ERRORLEVEL%==1 (

  echo [ info ] Installing babun
  call %builtins%\babun\install.bat

) else (

  echo [ info ] Babun is already installed, run the dotsys installer,
  echo          '.dotsys/installer.sh', in the babun shell to install dotsys.


)

:: Install dotsys

if %ERRORLEVEL%==0 (

  echo [ info ] When the babun installation is complete, run the dotsys installer,
  echo          '.dotsys/installer.sh', in the babun shell to install dotsys.


) else (

  echo [ fail ] Something when wrong with the installation. You must install,
  echo          some version of cygwin or msys and run .dotsys/installer.sh
  echo          manually to continue the installation.
)

:: Add usr/bin to path

:USRBIN

:: Documents\github\.dotsys\installer.sh

set usr_bin="\.babun\cygwin\usr\bin"
echo %PATH% |findstr /I /C:"%usr_bin%" 1>nul
if %ERRORLEVEL%==0 (
  echo [  ok  ] User cygwin bin already added to path
) else (
  setx PATH "%PATH%;%USERPROFILE%%usr_bin%" 1>nul
  echo [  ok  ] User cygwin bin added to path
)

refreshenv


@ECHO OFF

set profile_home=y
set /p profile_home="Would you like to make the cygwin home directory the same as your windows user profile: %USERPROFILE%? (y)es (n)o [y] : "

if /I %profile_home%==y (
  :: Sets $HOME to user's windows home rather then .babun/home/<username>
  setx HOME "%USERPROFILE%" 1>nul
)

:: install babun

choco install babun -y

if %ERRORLEVEL%==1 (
  echo [ fail ] Failed to install babun
  goto :eof
) else (
  echo [  ok  ] Installed babun
)




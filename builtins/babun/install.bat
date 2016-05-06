#!/usr/bin/powershell

# Sets $HOME to user's windows home rather then .babun/home/<username>
setx HOME $env:userprofile

# now install babun
# Im still confused if its better to install babun in an elevated prompt or not?
choco install babun

# Add cygwin bin to path so we get use of those tools on command line
setx PATH=%PATH%;C:\Users\arcte\.babun\cygwin\bin




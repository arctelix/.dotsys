#!/bin/bash
# Continue user install after exec restart
$(dotsys source core)
task "Install user repo and topics\n"
echo "installing"
dotsys install from "" 
#!/bin/bash

/usr/local/bin/box install commandbox-cfconfig 
/usr/local/bin/box install commandbox-dotenv

export MACHINE_SITE_ID={{site.site_id}}
export MACHINE_STAGE={{machine.stage}}
export CFML_ENV={{machine.stage}}
export ENVIRONMENT={{machine.stage}}

mkdir $HOME/machine-server-home/

/usr/local/bin/box server start name={{site.server_json}} saveSettings=false profile=production trayEnable=false openbrowser=false serverHomeDirectory=$HOME/machine-server-home/ 
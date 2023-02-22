#!/bin/bash

env MIX_ENV=prod PHX_SERVER=true SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH PHX_HOST=ammobox.local DB_PATH=/home/pi/amiibo.sqlite /home/pi/gamepad/apps/ui/_build/prod/rel/ui/bin/server

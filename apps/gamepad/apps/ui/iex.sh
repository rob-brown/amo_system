#!/bin/bash
mix assets.deploy
env MIX_ENV=prod PHX_HOST=localhost DB_PATH=amiibo.sqlite JOYCONTROL_MAIN="/home/pi/joycontrol/run_controller_cli.py" SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH PORT=4000 iex -S mix phx.server

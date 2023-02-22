#!/bin/bash
mix assets.deploy
env MIX_ENV=prod PHX_HOST=ammobox.local DB_PATH=/home/pi/amiibo.sqlite SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH PORT=4000 mix phx.server

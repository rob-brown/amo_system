# Gamepad

## Summary

The Gamepad code is able to emulate a Nintendo Switch Pro Controller. It
serves up a web interface on your local network to support loading amiibo.

## Assembly

This repo includes two hardware options.

1. A simple option based on the [Adafruit Joy Bonnet](./docs/joybonnet.markdown).

2. The [AmmoBox](./docs/ammobox.markdown), a built-from-scratch option including a
custom circuit board.

Alternatively, you can make your own hardware and adjust the code accordingly.

## Initial Setup

See the common [OS Setup doc](../../docs/os-setup.markdown) for details to
install an OS for the Raspberry Pi.

## Joycontrol Installation

First, you will need to install
[Joycontrol and its dependencies](https://github.com/poohl/joycontrol).
This involves editing some system files too. You may need to run the
`run_controller_cli.py` script to pair your Nintendo Switch to your Raspberry Pi.

## Gamepad Installation

You probably have `curl` and `cron` already installed. If you don't have them
installed, then you can do so like this:

```bash
sudo apt update
sudo apt install curl cron --yes
```

You can install the app for ammobox like this:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/gamepad/apps/ui/install.sh | bash -s -- ammobox
```

Or for the Joy Bonnet:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/gamepad/apps/ui/install.sh | bash -s -- joybonnet
```

The only difference is the platform name at the end.

> **WARNING:** You shouldn't just trust someone to run an arbitrary script on your
system, especially one that has root permissions like this one does. Take some
time and look over the script to ensure it's not doing anything nefarious. You
can also run the commands yourself to better see the effects.

Once you've installed the app, you will need to pair your Pi with your Nintendo
Switch. Then every time after your Pi boots, it will try to connect to your
Nintendo Switch.

## Web Interface

See the [web interface doc](./docs/web-interface.markdown) for details on how to use
the web interface to load and use amiibo.

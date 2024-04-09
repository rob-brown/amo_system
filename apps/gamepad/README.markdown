# Gamepad

## Summary

The Gamepad code is able to emulate a Nintendo Switch Pro Controller. It
serves up a web interface on your local network to support loading amiibo.

## Demo

With the gamepad, you can store all your amiibo in one place. Even with large
collections of amiibo you can organize them with tags. You can pull up any of
your trained amiibo and load them into Super Smash Bros. Ultimate. With the
shuffle button, you can even load the same amiibo multiple times.

[![Watch the video](https://img.youtube.com/vi/w329YQ2w-qM/hqdefault.jpg)](https://www.youtube.com/embed/w329YQ2w-qM)

You can also use it in other games such as Tears of the Kingdom. With the
shuffle function, you can load the same amiibo repeatedly, making this the
fastest way to farm items. Note, this only works with the proxy gamepad option
since you need a joystick and L button.

[![Watch the video](https://img.youtube.com/vi/g3VkRCFD8aM/hqdefault.jpg)](https://www.youtube.com/embed/g3VkRCFD8aM)

Item farming is also useful in other games such as Hyrule Warriors and Skyrim.
However, Hyrule Warriors limits the number of scans per day (5). Skyrim limits
one scan per day for each amiibo ID (not serial number). You will still need to
wait or change the system clock to scan more amiibo. Other games may have similar
restrictions.

## Search

Within an amiibo collection, you can search your amiibo based on name, character,
id, and tags. Any SSBU amiibo can be search by character, ex. `character:zelda`.
You can also create any tags you want and apply them to your amiibo. You can search
tags like this: `tag:tears_of_the_kindgom`. Note that spaces in tag names must
be replaced with underscores (`_`). IDs can be searched using base16 encoding.
Partial IDs can be searched by the first bytes. For example, the full ID
`id:01070000035a0902` is not necessary. Searching `id:01070000` or `id:0107` is
often sufficient. Names can be searched without any prefix, ex. `billy`. All search
terms are case insenstive.

## Assembly

This repo includes three hardware options.

1. A simple option based on the [Adafruit Joy Bonnet](./docs/joybonnet.markdown).

2. The [AmmoBox](./docs/ammobox.markdown), a built-from-scratch option including a
custom circuit board.

3. A bring-your-own-hardware option. You plug a USB gamepad into the Pi and the
buttons and sticks are [proxied](apps/proxy_gamepad) to the Nintendo Switch via bluetooth.

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

You can install the app for AmmoBox like this:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/gamepad/apps/hardware/install.sh | bash -s -- ammobox
```

For the Joy Bonnet:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/gamepad/apps/hardware/install.sh | bash -s -- joybonnet
```

The only difference is the platform name at the end.

If you instead want the proxy gamepad, run this:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/gamepad/apps/proxy_gamepad/install.sh | bash
```

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

## Troubleshooting

If you are having trouble with the web interface, make sure your cron file (ex. `/etc/cron.d/proxy`) is using the same
host name as your Pi. You can find the host name by running `hostname` from the console. If your host name is `raspberrypi`,
then make sure your cron file has `PHX_HOST=raspberrypi.local`.

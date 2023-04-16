# OS Setup

## Choose your microSD Card

The first step is to get your operating system (OS) installed on your microSD
card. An 8 GB microSD card is generally large enough and reasonably priced.
Other sizes should work fine.

## Install Raspberry Pi Imager

First, install the [Raspberry Pi Imager app](https://www.raspberrypi.com/software/),
and start it up.

## Pick Your OS

From here you will need to select the OS you want to install. All instructions in this
repo assume you are using the default 32-bit Raspberry Pi OS. You are welcome to use
a different OS. Just be aware you will be on your own if something doesn't work. Also,
the bluetooth library doesn't seem to work on a 64-bit OS.

![](./img/pick-os.png)

## Select your microSD Card

Next, insert your microSD card. Your computer may have a built-in reader. Or you
may need to use a USB adapter to write to your microSD card. It should be
automatically found and listed in the storage options. If not, try re-inserting your
microSD card.

## Configure your OS

Then, you need to configure the OS. Click the gear button.

The default hostname is `raspberrypi.local`. If you are setting up a gamepad, change
the name to `ammobox.local`. Otherwise, you will need to change the hostname when
running the code. If you have several Raspberry Pis running on the same network,
then you should pick a hostname other than the default.

For debugging, it's recommended to set up SSH. If you don't know what that is, then
you can ignore it.

The default username is `pi` and the password is `raspberry`. It's recommended to set
a different username and password.

You will also need to put in your wifi name and password so your Raspberry Pi can
connect to the network. If you don't, then you will need to use an ethernet cable to
connect your Raspberry Pi to your local network.

![](./img/configure-os.png)

## Write to your microSD Card

Finally, you are now ready to write the image to your microSD card. Simply click the
"WRITE" button.

![](./img/rpi-imager.png)

## Boot your OS

Once finished you can remove the microSD card and insert it into your Raspberry Pi.
When it powers up it will boot your newly installed OS.

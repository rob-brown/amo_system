# Tournament Runner

## Summary

The Tournament Runner code is able to emulate a Nintendo Switch Pro Controller. It
also uses a USB capture card to watch the live gameplay to load amiibo and determine
the winner. The tournament matches are pulled from Challonge and the results posted
back to Challonge.

## Initial Setup

See the common [OS Setup doc](../../docs/os-setup.markdown) for details to
install an OS for the Raspberry Pi.

## Joycontrol Installation

First, you will need to install
[Joycontrol and its dependencies](https://github.com/poohl/joycontrol).
This involves editing some system files too. You may need to run the
`run_controller_cli.py` script to pair your Nintendo Switch to your Raspberry Pi.

## OpenCV Installation

See the [Vision library](../vision/README.md) for details about installing OpenCV.

## Challonge API Key

See the [Challonge API documentation](https://api.challonge.com/v1) for instructions
to get your own Challonge API key. Keep your API key secret and don't publish it.

## USB Capture Card

See the [Vision library](../vision/README.md) for details about supported USB
capture cards.

## Tournament Runner Installation

You probably have `curl` and `cron` already installed. If you don't have them
installed, then you can do so like this:

```bash
sudo apt update
sudo apt install curl cron --yes
```

You can install the app like this:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/tournament_runner/install.sh | bash -s -- [CHALLONGE_API_KEY]
```

Replace `[CHALLONGE_API_KEY]` with your own API key.

<blockquote style="background-color:#FC6666; color:black">
⛔️ <strong>WARNING</strong>You shouldn't just trust someone to run an arbitrary script on your system, especially one that has root permissions like this one does. Take some time and look over the script to ensure it's not doing anything nefarious. You can also run the commands yourself to better see the effects.
</blockquote>

Once you've installed the app, you will need to pair your Pi with your Nintendo
Switch. Then every time after your Pi boots, it will try to connect to your
Nintendo Switch.

## Livebook

This repo includes an Elixir Livebook for controlling the tournaments. This is
simpler than using SSH and controlling everything from the command line. See the
[installation instructions](../../notebooks/README.md). Then run the [Tournament
Runner Livebook](../../notebooks/tournament_runner.livemd).

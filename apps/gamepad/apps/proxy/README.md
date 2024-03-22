# Proxy

## Summary

The proxy gamepad allows you to connect a USB gamepad to your Raspberry Pi. The Pi
the relays the commands to the Nintendo Switch via bluetooth. This has a couple advantages:

1. Adds NFC support to controllers that don't have it.

2. Allows you to store, search, and use your amiibo from a single interface instead
of handling the physical figures and cards.

This proxy has some inherent latency. It's not recommended for regular gameplay use.

## Supported Controllers

The following controllers are supported.

* [DualSense](https://www.playstation.com/en-us/accessories/dualsense-wireless-controller/) (PS5)
* [DualSense Edge](https://www.playstation.com/en-us/accessories/dualsense-edge-wireless-controller/) (PS5)
* Xbox 360 (Maybe)
* [GuliKit KingKong 2 Pro Controller](https://www.gulikit.com/productinfo/737791.html)
* [PDP](https://pdp.com/products/nintendo-switch-purple-camo-rematch-controller?_pos=1&_sid=e8ff57b3b&_ss=r)

The Nintendo Switch Pro Controller is **NOT** supported. The USB support is suprisingly bad.

If your favorite controller doesn't work, you can [add a mapping](lib/proxy/controller_mapping.ex).
Or you can add the configuration on the fly with the web interface.

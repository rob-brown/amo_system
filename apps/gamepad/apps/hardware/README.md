# Hardware

## Summary

This app contains the code specific to the AmmoBox and Joy Bonnet hardware. It is kept separate since
it runs `pigpio` which requires root permissions. The [`proxy`](../proxy_gamepad) option can be run
without this requirement.

Uses the same [web interface](../ui) as the [proxy gamepad](../proxy_gamepad).

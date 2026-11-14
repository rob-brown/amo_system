# picopad_proxy TODO

Goal: the proxy works with BOTH firmwares through the `Picopad` library (`apps/picopad`):

- the Raspberry Pi Pico firmware (`firmware/picopad`, Switch 1, Bluetooth Classic), and
- the nordicpad nRF52840 dongle (`firmware/nordicpad`, Switch 2, BLE, shows up as a Pro Controller 2).

They share one host protocol. Read `apps/picopad/TODO.md` (library work) and `firmware/nordicpad/TODO.md` (firmware work) for the details.

## What the proxy uses from the firmware

| Call | Command | On nordicpad |
|---|---|---|
| `Picopad.connect`, `status`, `firmware` | serial open, 0x01, 0xF1 | works (verified on hardware) |
| `hold`, `release_all`, `stick` | 0x10, 0x12, 0x13/0x14 | works (verified) |
| `load_amiibo`, `clear_amiibo` | 0x31-0x34, 0x37 | works (v3, 2048 bytes verified) |
| `start_advertising`, `stop_advertising`, `reconnect`, `forget_bonding` | 0x02, 0x03, 0x40, 0x41 | works (verified 2026-11-14) |
| events `connection_changed`, `amiibo_scanned`, `reconnect_success`/`failed`, `bonding_cleared` | 0xE0, 0xE1, 0xE4-0xE6 | sent (0xE5 not verified) |
| event `log` | 0xE7 | not sent |

`Picopad.disconnect/1` in the proxy only closes the serial port; it is not the Bluetooth disconnect command.

## Done

- [x] **Connection-changed event handling.** The manager already used the 7-byte parser; it is now covered by a test that feeds the real layout, and a malformed payload keeps the status.
- [x] **Commands the firmware does not support.** The library's `unknown_command` becomes `{:error, :not_supported}` (`PicopadProxy.Errors`). The status is left unchanged and nothing is broadcast on failure. `Errors.message/1` has the text for the UI ("Not supported by this firmware").
- [x] **Know which firmware is connected.** `ConnectionManager` detects it with `Picopad.firmware/1` and keeps it in its state, in `status/0` and in the `{:connection_changed, info}` broadcast.
- [x] **Status after radio commands.** The manager re-reads the real status after each successful command instead of assuming it (stopping advertising while paired used to claim `:connected`).
- [x] **Serial port picking.** `PicopadProxy.PortFinder` keeps the ports with a known vendor id (Pico 11914, Zephyr 12259), probes each with `Picopad.probe/2` and takes the first that answers, so the dongle's log port is skipped. The manager uses it at startup, on reconnect and through `ConnectionManager.auto_connect/0`, which the Detect button calls. The manual port list still shows every port.
- [x] **One process per serial port.** A held port (`{:open_failed, :eagain}`) is `{:error, :port_in_use}`; auto-connect reports `{:port_in_use, ports}`. Both set `last_error` with a readable message, which the pages show.
- [x] **Connect timeouts.** A port that opens but never answers is `{:error, :no_response}` and the manager stays up; the library no longer sends an exit signal when a port cannot be opened.
- [x] **Tests against both firmwares.** `test/picopad_proxy` runs the manager against the fake UART and fake firmware from `apps/picopad/test/support` (compiled into the proxy test build) for the Pico, nordicpad, an older nordicpad without the radio commands, a busy port and a silent port.
- [x] **Amiibo page with v3.** `PicopadProxy.AmiiboFile` parses an upload (size check, decrypt, `Amiibo.new`) and encrypts for the device; `AmiiboLive` uses it for upload, load and shuffle. Checked with the console-verified v3 (Kirby, "Skirby") and v2 dumps: both decrypt, read as v3/v2 and encrypt back byte for byte, so the same bytes the dongle already loaded on hardware. Fixed: a file that is not 540 or 2048 bytes made `encrypted?/1` raise and crash the page, `encrypt_binary!` raised on load, and rejected uploads were counted without a reason. Not covered by tests: the LiveView itself (its database is the real `~/picopad_proxy_amiibo.sqlite`); the file tests that need the fixtures skip when `firmware/nordicpad/test/fixtures` is missing. Not tried: a v3 dump on the Pico firmware (it may reject 2048 bytes; the page shows "The firmware rejected the amiibo").
- [x] **New events.** Reconnect success/failed and bonding cleared are broadcast on `"picopad:events"` as `:reconnect_success`, `:reconnect_failed`, `:bonding_cleared`.
- [x] **Pages.** Home and Picopad show the firmware (Switch 1 or 2) and controller type, "Unknown" for a missing player, readable errors, and a Detect action (it also runs when the page opens, without blocking it). The status wording says what the dongle's states mean ("Paired (console connected)", "Connected, not advertising"). LiveView tests with element ids cover both pages; the stale landing-page test was replaced.
- [x] **README** covers the dongle: supported hardware table, the two ports, Detect, the port-in-use case, v3 amiibo.
- [x] **Run against the dongle (2026-11-14).** `ConnectionManager.auto_connect` found the host port in 1.4 s past the log port, detected the nordicpad firmware and the Pro Controller, `reconnect` while connected was busy, stopping advertising while paired kept `:paired`, clear amiibo worked, connecting to the log port by name was `:no_response` with the manager still running.

## Open

- [ ] **Amiibo-scanned events in the UI.** The manager broadcasts `{:amiibo_scanned, payload}` on `"picopad:events"` (the dongle sends it, twice per scan on Enter Owner and Nickname) but no page shows it. If one does, treat it as a notification, not a count.
- [ ] **Amiibo write-back (later).** When the firmware can report a modified dump (`amiibo_read`, 0x35/0x36, and the write-complete event 0xE2) the proxy should fetch it and save it back into the collection. Depends on `firmware/nordicpad/TODO.md` (Amiibo, Host channel) and `Picopad.read_amiibo/1`.
- [ ] **USB gamepad mapping.** `UsbGamepad.ControllerMappings` only targets the buttons the library had before. The library now has `:c`, `:gl`, `:gr`, `:sl`, `:sr`; decide whether to map spare gamepad buttons to them, and check what the Pico firmware answers for them (it has none).
- [ ] **Hardware check list through the web pages** (the manager itself was run against the dongle, see Done). Not yet done through the pages: pairing from scratch, forget bonding, load an amiibo from the collection, and the USB gamepad buttons and sticks. Not done on the Pico at all in this round.

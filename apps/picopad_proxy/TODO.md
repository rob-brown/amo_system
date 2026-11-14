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
- [x] **Serial port picking.** `PicopadProxy.PortFinder` keeps the ports with a known vendor id (Pico 11914, Zephyr 12259), probes each with `Picopad.probe/2` and takes the first that answers, so the dongle's log port is skipped. The manager uses it at startup, on reconnect and through `ConnectionManager.auto_connect/0`. `PicopadLive` still lists ports for a manual connect and does not call it yet (UI phase).
- [x] **One process per serial port.** A held port (`{:open_failed, :eagain}`) is `{:error, :port_in_use}`; auto-connect reports `{:port_in_use, ports}`. Both set `last_error` with a readable message. The README does not mention it yet.
- [x] **Connect timeouts.** A port that opens but never answers is `{:error, :no_response}` and the manager stays up; the library no longer sends an exit signal when a port cannot be opened.
- [x] **Tests against both firmwares.** `test/picopad_proxy` runs the manager against the fake UART and fake firmware from `apps/picopad/test/support` (compiled into the proxy test build) for the Pico, nordicpad, an older nordicpad without the radio commands, a busy port and a silent port.
- [x] **New events.** Reconnect success/failed and bonding cleared are broadcast on `"picopad:events"` as `:reconnect_success`, `:reconnect_failed`, `:bonding_cleared`.

## Open

- [ ] **Connection status mapping on the pages.** The mapping is `disconnected -> :connected`, `advertising`, `pairing`, `ready -> :paired`. The dongle advertises by itself at boot and has no pairing-mode switch, so right after plugging it in the Home and Picopad pages show `:connected` or `:paired` without a "Start Advertising" step. Make sure the wording reads sensibly (for example, "ready" means the stored console is connected).
- [ ] **Use the firmware and errors in the UI.** Label the page (Switch 1 vs Switch 2, controller type), show `Errors.message/1` for failed commands, hide or disable controls a firmware lacks, and show the port-in-use and not-found messages. Add LiveView tests with element ids.
- [ ] **Auto-detect in `PicopadLive`.** Offer a "Detect" action that calls `ConnectionManager.auto_connect/0`, and mark which listed port answers.
- [ ] **Player number and amiibo-scanned events.** The manager forwards `player_number` (nil when the firmware sends 0xFF) and `:amiibo_scanned` (the dongle now sends it, twice per scan on Enter Owner and Nickname). The UI must show "unknown" for a missing player and treat scans as a notification, not a count.
- [ ] **Amiibo page with v3.** `amiibo_serialization` now supports v3 (2048 bytes). `AmiiboLive` calls `encrypt_binary!/1`, `decrypt_binary/1` and `Amiibo.new/1`; check upload, load and the readable error for a bad file, and whether an already-encrypted raw dump can be sent as-is (it can: the dongle accepted a raw 2048-byte dump and a game read it).
- [ ] **Amiibo write-back (later).** When the firmware can report a modified dump (`amiibo_read`, 0x35/0x36, and the write-complete event 0xE2) the proxy should fetch it and save it back into the collection. Depends on `firmware/nordicpad/TODO.md` (Amiibo, Host channel) and `Picopad.read_amiibo/1`.
- [ ] **USB gamepad mapping.** `UsbGamepad.ControllerMappings` only targets the buttons the library had before. The library now has `:c`, `:gl`, `:gr`, `:sl`, `:sr`; decide whether to map spare gamepad buttons to them, and check what the Pico firmware answers for them (it has none).
- [ ] **README.** `README.md` describes only the Pico. Add the nordicpad dongle: how to connect, the two ports, pairing on Controllers > Change Grip/Order (Switch 2), the "port in use" case with the automation daemon, and what differs.
- [ ] **Stale test.** `PageControllerTest` asserts the default Phoenix landing text and fails on a clean checkout.
- [ ] **Hardware check list for manual runs:** connect, start/stop advertising, pair, reconnect, forget bonding, load/clear amiibo, USB gamepad buttons and sticks.

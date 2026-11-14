# picopad (Elixir host library) TODO

This library (`apps/picopad`, module `Picopad`) is the source of truth for host control of both firmwares:

- the Raspberry Pi Pico firmware in `firmware/picopad` (Switch 1, Bluetooth Classic), and
- the nordicpad dongle firmware in `firmware/nordicpad` (Switch 2, BLE).

Both speak the same host protocol (COBS packets, `[len16][cmd][payload][crc8]`). nordicpad implements fewer commands than the Pico firmware (see `firmware/nordicpad/TODO.md`), so the library copes with a firmware that answers unknown-command.

## Done

- [x] **Connection-changed events.** `Protocol.parse_connection_changed_payload/1` parses the 7-byte event (`<<state, addr::6>>`); `parse_status_payload/1` stays for the 10-byte `get_status` reply. Both are tested with the exact layouts and reject each other's layout. `PicopadProxy.ConnectionManager` and `AutomationMCP.Connector` both use the new parser (the connector was still crashing on every connection change and is fixed and tested).
- [x] **`set_colors/2`** (0x43), `Picopad.set_colors(pid, body: ..., buttons: ..., highlight: ..., grip: ...)`. The Pico answers `{:error, :unknown_command}`.
- [x] **Buttons `:c`, `:gl`, `:gr`, `:sl`, `:sr`** for `hold`/`release` (bitfield) and `press` (ids 0x12 to 0x16). The Pico firmware has none of them: its answer is whatever the firmware gives (not yet checked on hardware). The button map now lives only in `Protocol`; `Picopad` used to carry a second copy.
- [x] **`read_amiibo/1`** was already ported (named `read_amiibo`, not `amiibo_read`). Tested at 540 and 2048 bytes against a fake firmware. A zero-size dump no longer asks for chunk -1.
- [x] **Unknown-command is a normal answer.** Every public function now returns `{:error, :unknown_command}` (or whichever status the firmware sent) instead of leaking `{:ok, %{status: ...}}`. Tested for every command nordicpad lacks.
- [x] **Firmware detection.** `Picopad.firmware(pid)` returns `{:ok, :picopad | :nordicpad}` from the version string ("nordicpad ..." means nordicpad). The string is the only signal today; ask for a dedicated capability byte if more firmwares appear. `supports?/2` was left out: the callers can use the unknown-command answer.
- [x] **Events.** 0xE4, 0xE5 and 0xE6 are named `:reconnect_success`, `:reconnect_failed`, `:bonding_cleared`. The event and status parsers live only in `Protocol` (the connection had a second copy).
- [x] **Tests.** `test/support` has a fake UART and a fake firmware for each of the two; golden byte layouts cover every request builder, status and bonding payloads, event names and status bytes. The test folder was renamed from `picopad_ex` to `picopad`.

## Open

- [ ] **Controller ids.** `get_status` returns 1 Joy-Con L, 2 Joy-Con R, 3 Pro Controller. nordicpad reports the Pro as 3 (verified on hardware). The Pico returns whatever `set_controller_type` selected.
- [ ] **Serial port ownership.** Only one process can open a serial port; a second one fails with `{:open_failed, :eagain}`. The automation daemon (`apps/automation_mcp`) auto-connects to the first port that answers and will hold the dongle's host port, which blocks `picopad_proxy` and scripts. `Picopad.connect/2` uses `start_link`, so a failed open also sends an exit signal to a caller that is not trapping exits; callers must trap exits or the library should return the error without linking.
- [ ] **Finding the host port.** The dongle exposes two serial ports and only the second answers the protocol. `automation_mcp` scans and keeps the first port that answers; consider a shared helper here.
- [ ] **Bonding status.** `parse_bonding_status_payload/1` expects 13 bytes (`<<bonded, addr::6, timestamp::32, count::16>>`); nordicpad will return the same layout once it implements 0x42.
- [ ] **Naming.** Stay `Picopad` for now; `nordicpad` is a firmware, not a library.

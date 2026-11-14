# nordicpad TODO

State on 2026-11-14: the nRF52840 dongle runs BTstack plus the open-source Zephyr controller (patched `CONN_INTERVAL_MIN`), pairs as a Pro Controller 2, keeps its pairing in flash, and takes host commands over a second USB serial port. Buttons, both sticks and v3 amiibo reads (Kirby verified on the dongle) work on the console.

## Amiibo

- [ ] **Writes.** The console writes when an amiibo is registered or changed (System Settings > amiibo > Enter Owner and Nickname > OK, and in games). The `nfc:` log lines already show the commands (`01.14` write is acked but ignored today). Work out the Switch 2 write sequence and ack, apply the data to the stored dump, and mirror the Switch 1 write ACK findings (sequential block ids, WriteDone).
- [ ] **Hand the modified dump back to the host.** Needs the amiibo read commands (0x35, 0x36) in the host-channel section below.
- [x] **Amiibo loaded while the console is already scanning** is now picked up (verified on the dongle 2026-11-14, system menu scan screen). The store has a generation counter, and `nfc_session_tick` signals the console like a scan start when the generation changes with an amiibo present and the console has an NFC session open. Before, a scan screen opened first never noticed a later load.
- [ ] **Re-verify v2 and the other v3 dumps on the dongle** (Meta Knight, King Dedede, a v2 dump). Only Kirby was scanned on the dongle; the others were verified on the Mac build.
- [ ] **The 32-byte per-amiibo header block** is a constant taken from a Kirby capture, not derived. Find where the console's value comes from.

## Host channel

The host protocol is the one in `firmware/picopad/src/host_protocol.c` (COBS packets, `[len16][cmd][payload][crc8]`). The dongle answers unknown-command (status 0x01, `HOST_STATUS_UNKNOWN_CMD`) to anything not in `src/host/host_commands.c`'s `COMMAND_TABLE`. Add each command as a handler in `src/host/handlers/` plus an entry in that table, with a test in `test/test_host_commands.c`. Payload formats below match the Pico firmware so the existing Elixir library works unchanged. Elixir side: `apps/picopad`.

Needed by `apps/picopad_proxy` (its Picopad page and connection status):

- [x] **Start advertising (0x02)** and **stop advertising (0x03)**. Done and verified on the dongle (2026-11-14): after a stop `get_status` reads disconnected and stays so (no re-advertise on disconnect); start gives advertising, pairing, ready as the console connects.
- [x] **Reconnect (0x40)**. Done and verified: ERROR with no stored pairing, OK after a stop with a stored pairing (advertising, then 0xE4, then pairing, ready), BUSY while connected. Not verified: BUSY while advertising only.
- [x] **Forget bonding (0x41)**. Done and verified: the link drops, 0xE6 is sent, the dongle advertises open, and the console on Change Grip/Order paired again by itself within 3 s.
- [x] **Events 0xE1, 0xE4, 0xE6.** Verified on hardware. 0xE1 (`<<0>>`) is sent each time the console starts a read; the console reads twice per scan on Enter Owner and Nickname, so expect two events per scan.
- [ ] **Reconnect failed (0xE5)** after the 30 s reconnect timeout is implemented but not verified on hardware (the console always reconnected at once).

Wanted, not needed by the proxy yet:

- [ ] **Amiibo read (0x35) and read chunk (0x36).** 0x35 has no payload and replies `<<size::little-16, chunk_size>>` (status AMIIBO_ERROR when nothing is loaded); 0x36 takes `<<chunk_index>>` and replies that slice of the stored dump (INVALID_PARAMS when out of range). This is how a host gets the dump back after the console writes to it, so it belongs with the amiibo write work above. `amiibo_store` already holds the data.
- [ ] **Amiibo set readonly (0x38)**, payload `<<0 | 1>>`, reply OK. Store the flag in `amiibo_store` and refuse console writes to the dump while it is set (needs the write support above to mean anything).
- [ ] **Set LED (0xF3)**, payload `<<mode>>`: 0 off, 1 on, 2 blink slow, 3 blink fast, 4 auto; INVALID_PARAMS above 4. On the Pico this drives the board LED. The nRF52840 dongle has a green LED and an RGB LED; pick which one and what "auto" means (for example following the connection state).
- [ ] **Get bonding status (0x42)**, no payload, reply 13 bytes: `<<bonded, address::6, timestamp::32 big-endian, count::16 big-endian>>`. Report whether the flash record exists and the console address from it; timestamp and count can be zero if there is nothing to track.
- [ ] **Disconnect (0x04)**, **set controller type (0x05)**, **MCU state (0x39) and debug (0x3A)**, **log level (0xF4)**: present on the Pico; decide per command whether the dongle needs it. Set controller type would need a profile switch at runtime (today the Pro profile is chosen at build time).
- [ ] **Controller-id check:** `get_status` now reports the profile's type; make sure any new command that mentions the controller uses the same host ids (1 Joy-Con L, 2 Joy-Con R, 3 Pro).

Events (the dongle only sends the connection-changed event, 0xE0, with a 7-byte payload `<<state, address::6>>` where the address is currently zeros):

- [ ] **Fill in the console address** in the connection-changed event and in `get_status` (`switch_address`) once the link has a peer.
- [x] **Amiibo scanned (0xE1)**, `<<0>>` for a read, sent when the console starts a read (verified, twice per scan). The write-request flag is never set until the write work exists.
- [ ] **Other events** the Pico sends: amiibo write complete (0xE2, with the write work), error (0xE3), log (0xE7, `<<level, text...>>`; optional, useful to forward the dongle log to the host instead of the first serial port). Reconnect success/failed (0xE4/0xE5) and bonding cleared (0xE6) are done.
- [ ] **Player number.** `get_status` reports `player` as 0xFF (none) always, so the proxy cannot show which player slot the console assigned. Unverified guess: the console sends the controller a player-lights command during init or after assignment. Look for it in the `req:` log lines (unhandled commands show up there), confirm it carries the player number, then store it and report it in `get_status` and the connection event. If the console sends nothing like it, drop this item.

## Controller behavior

- [ ] **Pro input report rate:** we send one report per connection interval (5 ms). The real Pro Controller 2 rate is unverified (no capture).
- [ ] **Home, Capture and C** are not covered by the console's button test; verify them another way.
- [ ] **Joy-Con L profile** and the regression with both real Joy-Cons wireless (case (a), not run).
- [ ] **The one-time 0x1e bounce per fresh pairing** is avoided only by patching the shared NCS tree (`dongle/zephyr_conn_interval_min.patch`). Keep the patch applied in the build instructions, or carry it as a west patch/fork.
- [ ] **Unexplained:** the 2026-11-10 night where the link ran 20+ minutes at interval 12 without a console update; the PHY update to 2M after reconnect is not decoded in the log.
- [ ] **Intermittent: re-pairing after forget bonding stuck once (2026-11-14).** Forget bonding with the console on Controllers > Change Grip/Order, after an amiibo scan session and with an amiibo loaded: the console connected every ~3 s, finished the MTU exchange, sent no command, and dropped the link after 2 s (`disconnected, reason 0x13`, log line `write to handle 0x0000 ignored (0 bytes)` just before). The state stayed `pairing`/`advertising` for 40+ s and clearing the amiibo did not help; rebooting the dongle (host command 0xF2) fixed it and the console paired at once. Not reproduced in three retries (library with and without an amiibo, and from the proxy page): each re-paired in about 3 s. Candidates: leftover console-side state from the scan session, or dongle BTstack state after an in-place disconnect and re-advertise. If it recurs, capture the log from the forget itself, and try forgetting twice or sending the reset before reaching for a reflash.

## Firmware and tooling

- [ ] **Soft DFU.** The factory Nordic bootloader only enters DFU on the RESET button; every flash needs a press. Options: MCUboot (needs a programmer or one-time DFU), or accept the button.
- [ ] **Dongle build and flash script.** Building (`west build ...`) and packaging (`nrfutil nrf5sdk-tools pkg generate ...`) are manual commands recorded only in `handoff.md`. `scripts/build.sh` and `scripts/flash.sh` still target the Pico.
- [ ] **Vendor BTstack.** `dongle_app/CMakeLists.txt` reads BTstack source from `~/code/pico-sdk/lib/btstack` (the pico-sdk checkout on the dev machine), so the dongle firmware cannot be rebuilt elsewhere without it. Vendor the tree or pin it as a submodule, and note the BTstack version.
- [ ] **Pico port:** `src/platform/pico_ble_platform.c` and the Pico build are untested since the CYW43 has no 2M PHY. Remove or keep.
- [ ] **Diagnostics cleanup:** the `NORDICPAD_DIAGNOSTIC_*` flags and the SoftDevice experiment confs (`dongle/hci_uart*.conf`) are no longer used by the dongle build; the SoftDevice-specific diagnostics were not re-run after the split.
- [ ] **Generated and fixture files:** `src/generated/identity_data.c` and `test/fixtures/` are gitignored and made from a capture (`scripts/extract_fixtures.exs`, `scripts/extract_nfc_fixture.exs`); a fresh checkout needs them to build the golden tests.
- [ ] **Hardware-in-the-loop checks** are manual (screenshots and the automation daemon); only the host-side C tests are automated.
- [ ] **Docs:** `docs/` was left out of the copy into `amiibo_system`; decide what to keep.

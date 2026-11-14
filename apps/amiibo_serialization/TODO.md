# amiibo_serialization TODO: v3 amiibo support

Goal: read, decrypt, edit and re-encrypt v3 amiibo (NTAG I²C Plus 2K, 2048-byte dumps, made for Kirby Air Riders) as well as v2 (NTAG215, 540 bytes), without changing any v2 result.

The format notes are in `~/Sync/Code/picopad/docs/v3-amiibo.md` (a working document from hardware captures, not an authority; where it and a real dump disagree, the dump wins). The firmware side already scans v3 dumps on a console, so the dumps below are known good.

## Status

v3 read/decrypt/edit/encrypt works and round-trips byte for byte on the three console-verified dumps (kirby, metaknight-registered, dedede-registered). v2 output is byte-identical to the pre-change baseline. Merged to main. Console tested in Kirby Air Riders (via amo-automation + picopad): the unmodified dump and a renamed v3 scan fully, but a v3 with a shuffled serial is rejected (error 2115-0548). Remaining work: decide what v3 `shuffle_serial/1` and `set_serial/2` do, accessor coverage, and the optional v3 to v2 conversion.

Key findings:

- The key seed is the raw tag bytes 0-7 (7-byte UID plus 0x00, no BCC). `DerivedKey` needed no change; only the HMAC (0x0C0) and app data (0x0E0) offsets differ from v2.
- A decrypted v3 binary is exactly 2048 bytes: the 520-byte internal layout, the 64 reserved bytes (tag 0x080-0x0BF), then tag bytes from 0x248 on (game-specific block, SRAM, config pages). Every accessor keeps its v2 offsets.
- Formats are detected by size, and for encrypted v3 by the amiibo id format byte (tag offset 0x05B = 0x03). See `AmiiboSerialization.Format`.

## Done

- [x] **Add v3 tests from real dumps.** `test/private_dumps_test.exs`, gated by `AMIIBO_KEY_PATH`, `AMIIBO_V3_DUMP_DIR` and `AMIIBO_V2_DUMP`; excluded (not failed) when unset. `test/format_test.exs` covers detection with synthetic data.
- [x] **Detect the format.** `Format.of_tag/1`, `Format.of_decrypted/1`; `encrypted?/1` no longer relies on BCC for v3.
- [x] **Make `tag_to_internal` / `internal_to_tag` format-aware.** v2 path byte-identical.
- [x] **Preserve everything outside the internal layout.** Reserved bytes, game-specific block, SRAM and config pages survive decrypt then encrypt.
- [x] **Verify the key derivation against real dumps.** All three dumps decrypt with valid HMACs.
- [x] **Round-trip tests.** v3 and v2, including both registered dumps.
- [x] **Extend `Amiibo` for v3.** `new/1` accepts 2048 bytes, `format/1` added, `serial_number/1`, `set_serial/2` and `shuffle_serial/1` handle the direct 7-byte UID. `UID` itself is unchanged.
- [x] **README.** v2 vs v3 section added.

## Remaining

- [x] **Test v3 with `apps/picopad_proxy`.** The proxy suite passes (70/70) on main. Rename, shuffle and rename plus shuffle through `PicopadProxy.AmiiboFile` were checked on all three v3 dumps and the v2 dump: the result re-parses with valid hashes, the id, owner and unmanaged tail are untouched, and the nickname truncates to 10 characters.
- [ ] **Accessor coverage on v3 dumps.** Only nickname, amiibo id, serial number, `shuffle_serial` and `rename` are tested. Add checks for `owner_name/1`, `mii_profile/1`, `app_id/1`, `program_id/1`, `update_hash/1` and `set_id/2`; they use the shared internal offsets, so they should work.
- [x] **Console test in KAR (2026-11-14).** Unmodified kirby: scans, "Skirby". Renamed metaknight-registered ("Renamed"): scans with the new nickname, fashion, FP level and proficiency intact. Kirby with a shuffled serial (UID changed, re-encrypted with valid HMACs): fails with error 2115-0548.
- [ ] **v3 serial change is rejected by the game.** The firmware returns 32 zero bytes for READ_SIG regardless of UID, and the original UID scans, so the signature is not what fails. Something UID-bound that we preserve verbatim (the game-specific block from 0x388, or the authenticated SRAM bytes) most likely fails. Decide: make v3 `shuffle_serial/1` and `set_serial/2` return an error (and have `AmiiboLive` disable or hide Shuffle for v3) instead of producing a file the game refuses. Note that Switch 2 keys would be needed to support it properly.
- [ ] **v3 to v2 conversion (low priority).** Sketch: set byte 7 of the amiibo id to 0x02, build a 540-byte tail with v2 config pages, encrypt through the v2 path. The console may validate more than the format byte.

## Open questions

- Whether v3 dumps from other tools (TagMo, Amiiboss) differ in layout from the console-verified dumps the tests use. The reserved and trailing bytes are preserved verbatim, so decrypt/encrypt should be unaffected, but this is untested.
- Callers: `Amiibo.format/1` is new, and decrypted v3 binaries are 2048 bytes. No new error returns were added. List for the proxy agent (`apps/picopad_proxy/TODO.md`).

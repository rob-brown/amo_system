# AmiiboSerialization

This package simply reads and writes amiibo files. This includes encrypting/decrypting the files. The implementation is based on PyAmiibo (https://github.com/tobywf/pyamiibo).

## Formats

| | v2 | v3 |
|---|---|---|
| Chip | NTAG215 | NTAG I²C Plus 2K |
| Encrypted size | 540 bytes | 2048 bytes |
| UID | 7 bytes with BCC bytes interleaved | 7 bytes stored directly, byte 7 is 0x00 |
| Data HMAC / app data | 0x080 / 0x0A0 | 0x0C0 / 0x0E0 |
| Amiibo id format byte (tag offset 0x05B) | 0x02 | 0x03 |

The encryption and key derivation are identical, and the same `key_retail.bin` works for both. `AmiiboSerialization.Format` detects the format from the size and the amiibo id.

A decrypted binary is always the 520 byte internal layout followed by everything else from the tag, so every accessor in `AmiiboSerialization.Amiibo` uses the same offsets for both formats. For v3 that remainder is 1528 bytes: the 64 reserved bytes (tag 0x080-0x0BF) and the data from tag 0x248 on (game-specific block, SRAM, config pages). It is kept byte for byte and written back on encrypt, because it cannot be edited without Switch 2 keys. `Amiibo.format/1` returns `:v2` or `:v3`.

For v3, `set_serial/2` and `shuffle_serial/1` rewrite the 7 byte UID, which is part of the key seed. Whether a console accepts a changed v3 UID has not been verified.

## Tests

Tests that need real dumps are excluded unless these are set: `AMIIBO_KEY_PATH` (160 byte `key_retail.bin`), `AMIIBO_V3_DUMP_DIR` (directory holding `kirby.bin`, `metaknight-registered.bin` and `dedede-registered.bin`) and `AMIIBO_V2_DUMP` (a 540 byte dump). Never commit the dumps or the key.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dual-language embedded systems project that emulates a Nintendo Switch Pro Controller using a Raspberry Pi Pico 2 W (RP2350). It consists of:

1. **C firmware** - Runs on the Pico 2 W, handles Bluetooth HID and Switch protocol
2. **Elixir library** (`picopad/`) - Host-side library for controlling the Pico via USB serial

The firmware implements the complete Nintendo Switch Pro Controller protocol including:
- Bluetooth HID communication using BTstack
- Button and analog stick emulation
- SPI flash emulation for calibration data
- NFC/amiibo reading and emulation
- USB serial protocol for host control (COBS-encoded packets with CRC8)

## Documentation

The `docs/` directory contains detailed protocol specifications:

- **docs/picopad-spec.markdown** - Complete Nintendo Switch Controller Bluetooth HID Protocol specification including SDP service records, HID report formats, subcommands, button/stick encoding, SPI flash memory layout, MCU/NFC protocol, and timing requirements
- **docs/nfc.markdown** - NFC Type 2 Tag (NTAG215) emulation implementation guide covering ISO/IEC 14443-3A protocol, command formats (READ, WRITE, GET_VERSION, etc.), memory layout, and authentication
- **docs/protocol.markdown** - Host-to-Pico communication protocol design covering USB CDC serial vs UART options, packet framing, and command/response formats

Refer to these when implementing or debugging protocol-level features.

## Build Commands

### C Firmware (Pico 2 W)

```bash
# Build firmware (requires PICO_SDK_PATH environment variable)
./scripts/build.sh

# Output: build/switch_controller.uf2
```

### C Tests

```bash
# Build and run host-side protocol tests
cd test
mkdir -p build
cd build
cmake ..
make
ctest --output-on-failure

# Or run specific test:
./test_protocol
./test_cobs
./test_integration
```

### Elixir Library

```bash
cd picopad

# Get dependencies
mix deps.get

# Run tests
mix test

# Format code (MUST run after changes per global rules)
mix format
```

## Architecture

### Firmware Architecture (C)

The firmware is structured around these core modules:

- **main.c** - Entry point, BTstack event loop, LED control, host protocol polling
- **bt_hid.c/h** - Bluetooth HID layer (SDP service records, connection management)
- **switch_protocol.c/h** - Nintendo Switch Pro Controller protocol implementation
  - Handles subcommands (device info, SPI flash reads, MCU config, etc.)
  - Manages NFC state machine for amiibo emulation
  - Builds input reports (0x21, 0x30, 0x31)
- **controller_state.c/h** - Button and stick state management
- **spi_flash_data.c/h** - Emulated SPI flash with calibration data
- **host_protocol.c/h** - USB serial protocol for host communication
- **cobs.c/h** - Consistent Overhead Byte Stuffing (packet framing)
- **crc8.c/h** - CRC8 checksum (polynomial 0x07)

### Protocol Flow

1. **Pairing Phase**: Switch sends subcommands to query device info, calibration, player lights
2. **Connected Phase**: Firmware sends 60Hz input reports, responds to MCU/NFC commands
3. **NFC State Machine**: `NONE` → `POLL` → `PENDING_READ` → `READING` → `POLL_AGAIN`

### Host Protocol (USB Serial)

The Pico exposes a USB serial interface that accepts COBS-encoded packets:

- Packet format: `[length_high] [length_low] [command] [payload...] [crc8]`
- Commands defined in `host_protocol.h` (e.g., `HOST_CMD_PRESS_BUTTON`, `HOST_CMD_AMIIBO_LOAD`)
- Events sent to host (e.g., `HOST_EVT_CONNECTION_CHANGED`, `HOST_EVT_AMIIBO_SCANNED`)

### Elixir Library Architecture

- **Picopad** - Main API module (press buttons, load amiibo, etc.)
- **Picopad.Connection** - Manages Circuits.UART connection and command/response handling
- **Picopad.Protocol** - Packet building and parsing
- **Picopad.COBS** - COBS encoding/decoding

## Key Implementation Details

### NFC/Amiibo Protocol

The Switch MCU protocol for NFC reading uses a 3-packet sequence to transfer amiibo data:

1. **Packet 1**: 15-byte header + 7-byte UID + 45-byte fixed block + first 245 bytes of amiibo
2. **Packet 2**: 7-byte header + remaining 295 bytes of amiibo (bytes 245-540)
3. **Packet 3**: 16-byte header + 7-byte UID (finish)

UID extraction: Take bytes `[0:2]` + skip BCC at `[3]` + bytes `[4:7]` from amiibo dump.

Critical: Status response bytes 12-13 must be `01 02` (NTAG215 type), not `04 44` (ATQA values).

### Controller Type Configuration

Change controller type in `main.c`:

```c
controller_state_init(&controller, CONTROLLER_PRO);      // Pro Controller
controller_state_init(&controller, CONTROLLER_JOYCON_L); // Left Joy-Con
controller_state_init(&controller, CONTROLLER_JOYCON_R); // Right Joy-Con
```

### Button Encoding

Buttons are encoded as 3-byte bitmasks in the Switch protocol (see `controller_state.h` for bit positions). The host protocol uses button IDs mapped to button_t enum values.

## Environment Setup

Requires these environment variables:

- `PICO_SDK_PATH` - Path to pico-sdk (version 2.0.0+ for RP2350 support)
- `PATH` - Must include ARM GCC toolchain (`/opt/arm-gnu-toolchain/bin`)

## Common Development Workflow

1. Make changes to firmware C code
2. Build with `./scripts/build.sh`
3. Flash to Pico 2 W:
   - Hold BOOTSEL, connect USB, release BOOTSEL
   - Copy `build/switch_controller.uf2` to mounted drive
4. Test via Elixir:
   ```elixir
   {:ok, pid} = Picopad.connect("/dev/ttyACM0")
   Picopad.press(pid, :a)
   Picopad.status(pid)
   ```

## Testing Strategy

- **C tests**: Protocol unit tests run on host machine (no Pico required)
- **Integration testing**: Use Elixir library to test end-to-end firmware behavior
- Tests are in `test/` for C and `picopad/test/` for Elixir

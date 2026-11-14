# Picopad Proxy

A Phoenix LiveView web application that provides web-based control and USB gamepad proxying through the Picopad hardware.

## Overview

Picopad Proxy enables you to:
- Connect to Picopad hardware via USB serial
- Manage Bluetooth pairing with Nintendo Switch
- Proxy USB gamepad inputs to Picopad → Switch
- Manage amiibo collection and loading
- Works cross-platform (Linux and macOS)

This replaces the existing `gamepad` app's Joycontrol (Python Bluetooth emulation) approach with native Picopad hardware control.

## Supported hardware

The proxy talks to either of two devices through the `Picopad` library (`apps/picopad`). Both speak the same USB serial host protocol, and the proxy detects which one is connected.

| | Raspberry Pi Pico 2 W | nordicpad nRF52840 dongle |
|---|---|---|
| Firmware | `firmware/picopad` | `firmware/nordicpad` |
| Console | Switch 1 (Bluetooth Classic) | Switch 2 (Bluetooth LE), shows up as a Pro Controller 2 |
| Serial ports | one | two: the first is a text log, the second is the host channel |
| Amiibo | v2 (540 bytes) | v2 (540 bytes) and v3 (2048 bytes, Kirby Air Riders) |
| Advertising | starts when you click "Start Advertising" | advertises by itself at boot, with the stored console when there is one |

The Home and Picopad pages show which device is connected. A command the firmware does not implement shows "Not supported by this firmware" and leaves the status alone.

## Features

### Core Functionality

- **Picopad Connection Management**: Connect/disconnect via USB serial, manage Bluetooth advertising and pairing
- **USB Gamepad Support**: Cross-platform gamepad input via GilRs (Rust library)
  - Supports Xbox, PlayStation, Switch Pro, and generic controllers
  - Automatic button/stick mapping to Switch controls
  - Hotplug support
- **Amiibo Management**: Browse collection, upload .bin files, load to Picopad
- **Real-time Updates**: Phoenix PubSub for live status updates across all pages

### Architecture

```
USB Gamepad → GilrsEx (Rustler NIF) → EventProcessor → InputTracker → Picopad API → Switch
```

#### Components

**gilrs_ex** - New Rustler NIF package providing cross-platform gamepad support:
- Rust bindings to GilRs library
- Event-based API for button/axis changes
- Connection/disconnection detection
- Works on Linux (evdev) and macOS (IOKit)

**picopad_proxy** - Phoenix LiveView application:
- `ConnectionManager`: Manages Picopad lifecycle and Bluetooth state
- `InputTracker`: Tracks button/stick state, adapted from gamepad app
- `UsbGamepad.Reader`: Polls gamepad events via GilrsEx
- `UsbGamepad.EventProcessor`: Maps GilRs events to Switch controls
- LiveView pages: Home (dashboard), Picopad (connection), Gamepad (USB config), Amiibo (management)

## Installation

### Prerequisites

1. **Rust toolchain** (required for Rustler compilation):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **macOS only**: Xcode Command Line Tools:
   ```bash
   xcode-select --install
   ```

3. **Linux only**: Input device permissions:
   ```bash
   # Add user to input group
   sudo usermod -a -G input $USER
   # Log out and back in for changes to take effect
   ```

### Setup

```bash
cd apps/picopad_proxy

# Install dependencies (includes compiling Rust NIFs)
mix deps.get

# Start the Phoenix server
mix phx.server
```

Visit `http://localhost:4000` in your browser.

## Usage

### 1. Connect Picopad

1. Plug in the Pico or the nRF52840 dongle via USB
2. Navigate to "Picopad Connection" page (it tries to detect the device when it opens)
3. Click "Detect", or select the serial port from the dropdown and click "Connect". The dongle has two ports; "Detect" probes them and picks the one that answers, and for a manual connect pick the second one (macOS `/dev/cu.usbmodem...3`, Linux `ttyACM1`)
4. Pico: click "Start Advertising" to make it discoverable. Dongle: it is already advertising, so the status goes to Paired once the console connects
5. Pair with the console on Controllers → Change Grip/Order (Switch 1 and Switch 2)
6. "Reconnect to Console" starts advertising to the stored console again, and "Forget Bonding" clears the pairing so you can pair from scratch

### 2. Connect USB Gamepad

1. Plug in USB gamepad
2. Navigate to "USB Gamepad" page
3. Gamepad should appear automatically in the connected list
4. Inputs are automatically forwarded to Switch via Picopad

### 3. Manage Amiibo

1. Navigate to "Amiibo Management" page
2. Upload .bin files via drag-and-drop or file picker
3. Click "Load to Picopad" to load an amiibo
4. Use amiibo in-game as normal
5. Click "Clear Amiibo" when done

## Controller Mapping

USB gamepad buttons are automatically mapped to Switch controls:

| USB Button | Switch Button |
|------------|---------------|
| South (A/✕) | B |
| East (B/○) | A |
| North (X/□) | X |
| West (Y/△) | Y |
| D-Pad | D-Pad |
| Left Trigger | ZL |
| Left Shoulder | L |
| Right Trigger | ZR |
| Right Shoulder | R |
| Select | Minus |
| Start | Plus |
| Mode | Home |
| Left Thumb | L Stick |
| Right Thumb | R Stick |

Analog sticks are mapped 1:1 to Switch left/right sticks.

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

## Architecture Details

### Coordinate Translation

The InputTracker translates coordinate systems:
- **Joycontrol range**: 0-4096 (center at 2048)
- **Picopad range**: -32768 to 32767 (center at 0)

```elixir
defp translate_coord(joycontrol_value) do
  percent = (joycontrol_value - 2048) / 2048.0
  trunc(percent * 32767)
end
```

### Event Flow

1. GilRs polls USB gamepad for events (10ms interval)
2. EventProcessor maps button/axis names to Switch controls
3. InputTracker accumulates state changes
4. State is sent to Picopad via API (with 20ms debouncing)
5. Picopad forwards to Switch via Bluetooth HID

### State Management

- **ConnectionManager**: Picopad connection state (disconnected → connected → advertising → pairing → paired), plus which firmware is connected. After each Bluetooth command it re-reads the real status from the device
- **InputTracker**: Current button/stick state (held buttons, stick positions)
- **Reader**: Connected gamepad list (ID → name mapping)

### PubSub Topics

- `picopad:connection` - Connection state changes (status, port, firmware, controller, player number when the firmware reports it, last error)
- `picopad:events` - Amiibo loaded/cleared/scanned, reconnect success/failed, bonding cleared
- `gamepad:events` - Gamepad connected/disconnected events

## Troubleshooting

### macOS: GilRs fails to detect gamepad

Make sure the controller is supported. Most modern controllers (Xbox, PS4/PS5, Switch Pro) work out of the box.

### Linux: Permission denied on /dev/input

Ensure your user is in the `input` group:
```bash
groups | grep input
```

If not, add yourself and log out/in:
```bash
sudo usermod -a -G input $USER
```

### Picopad connection fails

1. Check USB cable (must support data, not just power)
2. Use "Detect" or pick the right serial port. For the dongle that is the second of its two ports; connecting to the first one (the log) fails with "The port did not answer the Picopad protocol"
3. "Port in use by another program" means something else holds the serial port, and only one process can open it. The automation daemon (`apps/automation_mcp`) connects to the first port that answers when it starts, so stop it or let it be the only one using the device. Scripts and a second proxy fail the same way
4. Try unplugging and replugging the device

### Amiibo fails to load

1. Verify the device is connected
2. Check the .bin file is a 540 byte (v2) or 2048 byte (v3) dump; other sizes are rejected with the reason shown on the page
3. A v3 dump needs the nordicpad dongle; the Pico firmware may reject it ("The firmware rejected the amiibo")
4. Ensure the file is not corrupted and `key_retail.bin` is the right key
5. Try clearing and reloading

## License

This is part of the Amiibo Modular Open System (AMO System) monorepo.

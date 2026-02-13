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

1. Plug in Picopad via USB
2. Navigate to "Picopad Connection" page
3. Select the serial port from the dropdown
4. Click "Connect"
5. Click "Start Advertising" to make the Picopad discoverable
6. Pair with Nintendo Switch (Controllers → Change Grip/Order)

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

- **ConnectionManager**: Picopad connection state (disconnected → connected → advertising → paired)
- **InputTracker**: Current button/stick state (held buttons, stick positions)
- **Reader**: Connected gamepad list (ID → name mapping)

### PubSub Topics

- `picopad:connection` - Connection state changes, player number updates
- `picopad:events` - Amiibo loaded/cleared events
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
2. Verify correct serial port selected
3. Ensure no other application is using the port
4. Try unplugging and replugging Picopad

### Amiibo fails to load

1. Verify Picopad is connected
2. Check .bin file is valid (540 or 532 bytes)
3. Ensure file is not corrupted
4. Try clearing and reloading

## License

This is part of the Amiibo Modular Open System (AMO System) monorepo.

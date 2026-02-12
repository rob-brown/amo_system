# Nintendo Switch Controller Emulator for Raspberry Pi Pico 2 W

This project emulates a Nintendo Switch Pro Controller using a Raspberry Pi Pico 2 W. It implements the complete Bluetooth HID protocol required for the Switch to recognize and communicate with the controller.

## Features

- Emulates Pro Controller, Joy-Con (L), or Joy-Con (R)
- Full button and analog stick support
- Proper SPI flash emulation for calibration data
- 60Hz input report rate after pairing
- LED status indication (fast blink = advertising, solid = connected)

## Requirements

### Hardware

- Raspberry Pi Pico 2 W (RP2350 with CYW43439 wireless)
- USB cable for programming and power

### Software

- [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk) (version 2.0.0 or later)
- CMake (version 3.13 or later)
- ARM GCC toolchain (`arm-none-eabi-gcc`)
- Git

## Setup Instructions

### 1. Install Prerequisites

#### macOS

```bash
brew install cmake git

# Download ARM GNU Toolchain 14.2
cd /tmp
curl -LO https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi.tar.xz

# Extract to /opt
sudo mkdir -p /opt/arm-gnu-toolchain
sudo tar -xf arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi.tar.xz -C /opt/arm-gnu-toolchain --strip-components=1

# Add to PATH (add this to your ~/.zshrc or ~/.bashrc)
export PATH="/opt/arm-gnu-toolchain/bin:$PATH"
```

#### Ubuntu/Debian

```bash
sudo apt update
sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential git
```

#### Windows

Install the official [Raspberry Pi Pico Windows installer](https://github.com/raspberrypi/pico-setup-windows) which includes all required tools.

### 2. Clone and Set Up the Pico SDK

```bash
git clone https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk
git submodule update --init
cd ..
```

Set the SDK path environment variable:

```bash
export PICO_SDK_PATH=$(pwd)/pico-sdk
```

Add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) for persistence:

```bash
echo 'export PICO_SDK_PATH=/path/to/pico-sdk' >> ~/.zshrc
```

### 3. Build the Project

```bash
# From the project root
./scripts/build.sh
```

If successful, you'll see `switch_controller.uf2` in the `build/` directory.

## Installation

### Method 1: UF2 Bootloader (Recommended)

1. Hold the **BOOTSEL** button on the Pico 2 W
2. While holding BOOTSEL, connect the USB cable to your computer
3. Release BOOTSEL - the Pico appears as a USB drive named `RPI-RP2` or `RP2350`
4. Drag and drop `switch_controller.uf2` onto the drive
5. The Pico will automatically reboot and start running

### Method 2: Picotool

If you have `picotool` installed:

```bash
picotool load switch_controller.uf2
picotool reboot
```

## Usage

1. **Power the Pico 2 W** via USB or external 5V supply
2. The onboard LED will blink rapidly indicating advertising mode
3. On your Nintendo Switch, go to:
   - **Home Menu** → **Controllers** → **Change Grip/Order**
4. The Switch will discover "Pro Controller" and connect
5. Once connected, the LED stays solid
6. Press A or L+R to confirm the controller in the grip menu

### Demo Mode

The default firmware includes a demo that cycles through button presses every 2 seconds:
- A → B → X → Y → Stick Up → Stick Down → Stick Left → Stick Right

This helps verify the connection is working correctly.

## Customization

### Changing Controller Type

Edit `main.c` and change the controller type:

```c
// Choose one:
controller_state_init(&controller, CONTROLLER_PRO);      // Pro Controller
controller_state_init(&controller, CONTROLLER_JOYCON_L); // Left Joy-Con
controller_state_init(&controller, CONTROLLER_JOYCON_R); // Right Joy-Con
```

### Adding Physical Buttons

Connect buttons to GPIO pins and modify `main.c`:

```c
#include "hardware/gpio.h"

#define BUTTON_A_PIN 2
#define BUTTON_B_PIN 3

void setup_gpio_buttons(void) {
    gpio_init(BUTTON_A_PIN);
    gpio_set_dir(BUTTON_A_PIN, GPIO_IN);
    gpio_pull_up(BUTTON_A_PIN);

    gpio_init(BUTTON_B_PIN);
    gpio_set_dir(BUTTON_B_PIN, GPIO_IN);
    gpio_pull_up(BUTTON_B_PIN);
}

void read_buttons(void) {
    controller_set_button(&controller, BTN_A, !gpio_get(BUTTON_A_PIN));
    controller_set_button(&controller, BTN_B, !gpio_get(BUTTON_B_PIN));
}
```

### Available Buttons

```c
BTN_A, BTN_B, BTN_X, BTN_Y
BTN_L, BTN_R, BTN_ZL, BTN_ZR
BTN_PLUS, BTN_MINUS, BTN_HOME, BTN_CAPTURE
BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT
BTN_L_STICK, BTN_R_STICK
BTN_SL_L, BTN_SR_L  // Joy-Con (L) side buttons
BTN_SL_R, BTN_SR_R  // Joy-Con (R) side buttons
```

### Analog Stick Control

```c
// Set specific values (0x000 to 0xFFF range)
controller_set_stick(&controller, true,  0x800, 0x800);  // Left stick center
controller_set_stick(&controller, false, 0x800, 0x800);  // Right stick center

// Use calibrated positions
controller_set_stick_center(&controller, true);  // Left stick to center
controller_set_stick_up(&controller, true);      // Left stick full up
controller_set_stick_down(&controller, true);    // Left stick full down
controller_set_stick_left(&controller, true);    // Left stick full left
controller_set_stick_right(&controller, true);   // Left stick full right
```

## Troubleshooting

### Controller Not Appearing

- Ensure you're in the "Change Grip/Order" menu on the Switch
- Check that the LED is blinking (advertising mode)
- Try power cycling both the Pico and the Switch
- Move closer to the Switch (Bluetooth range)

### Connection Drops Immediately

- The Switch may have too many paired controllers. Go to **System Settings** → **Controllers and Sensors** → **Disconnect Controllers** and remove old pairings

### Buttons Not Registering

- Verify the controller fully paired (LED solid, not blinking)
- Check that you exited the "Change Grip/Order" menu after pairing
- The demo mode only sends one button press every 2 seconds

### Build Errors

- Ensure `PICO_SDK_PATH` is set correctly
- Verify you have the Pico SDK submodules: `cd $PICO_SDK_PATH && git submodule update --init`
- Check that you're using Pico SDK 2.0.0+ for Pico 2 W support

### USB Serial Debug Output

Connect via USB and open a serial terminal at 115200 baud to see debug messages:

```bash
# macOS
screen /dev/tty.usbmodem* 115200

# Linux
screen /dev/ttyACM0 115200

# Windows (use PuTTY or similar, check Device Manager for COM port)
```

## Project Structure

```
gamepad/
├── CMakeLists.txt           # Build configuration
├── pico_sdk_import.cmake    # SDK import helper
├── README.markdown          # This file
└── src/
    ├── btstack_config.h     # Bluetooth stack configuration
    ├── bt_hid.c/h           # Bluetooth HID implementation
    ├── controller_state.c/h # Button/stick state management
    ├── main.c               # Application entry point
    ├── spi_flash_data.c/h   # Flash memory emulation
    └── switch_protocol.c/h  # Switch HID protocol handler
```

## Protocol Reference

See `joycontrol-spec.markdown` in the parent directory for complete protocol documentation including:

- Bluetooth SDP service records
- HID report formats
- Subcommand specifications
- Button and stick encoding
- Timing requirements

## License

This project is provided for educational and personal use. Nintendo Switch is a trademark of Nintendo.

## Acknowledgments

- [joycontrol](https://github.com/mart1nro/joycontrol) - Python implementation reference
- [Nintendo Switch Reverse Engineering](https://github.com/dekuNukem/Nintendo_Switch_Reverse_Engineering) - Protocol documentation
- [BTstack](https://github.com/bluekitchen/btstack) - Bluetooth stack

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Amiibo Modular Open System (AMO System)** - a comprehensive toolkit for working with and automating amiibo on Nintendo Switch. The system includes:

- Bluetooth controller emulation (Pro Controller, Joy-Con)
- Computer vision for automated gameplay
- Amiibo file reading/writing and encryption/decryption
- Tournament automation for Super Smash Bros. Ultimate
- Web interface for amiibo management
- Embedded firmware for Raspberry Pi Pico 2 W

## Repository Structure

This is a **monorepo** containing multiple independent Elixir applications with local path dependencies, plus embedded C firmware:

- **apps/** - Independent Elixir applications (not an Umbrella project)
- **firmware/** - Embedded C firmware projects
- **notebooks/** - Livebook notebooks for interactive workflows
- **docs/** - Documentation

## Key Applications

### Core Libraries

- **amiibo_serialization** - Read/write/encrypt/decrypt amiibo files (based on PyAmiibo)
- **ssbu** - Extract SSBU-specific information from amiibo (character data, stats)
- **vision** - Computer vision automation using OpenCV and capture cards (Genki Shadowcast)
- **joycontrol** - Wrapper for controlling Nintendo Switch via Bluetooth
- **autopilot** - Automation framework combining vision and controller input with Lua scripting

### Hardware Control

- **picopad** (Elixir library at `apps/picopad/`) - Host library for controlling Pico via USB serial
- **picopad** (C firmware at `firmware/picopad/`) - Raspberry Pi Pico 2 W firmware that emulates Nintendo Switch controllers
  - See `firmware/picopad/CLAUDE.md` for detailed firmware development guidance
  - Implements complete Switch Pro Controller Bluetooth HID protocol
  - NFC/amiibo reading and emulation
  - USB serial protocol for host control (COBS-encoded packets)

- **gamepad** - Web interface for amiibo management on Raspberry Pi
  - Umbrella project with sub-apps in `apps/gamepad/apps/`
  - Serves local network web UI for loading/organizing amiibo collections
  - Supports hardware variants (Joy Bonnet, AmmoBox, proxy gamepad)

### Automation & Tournaments

- **rabbit_driver** - RabbitMQ-based automation framework for running Nintendo Switch automations
  - Language-agnostic (any language with AMQP support can control it)
  - Topic-based messaging for image processing, script execution, logging
  - Designed for Squad Strike and other game automations

- **tournament_runner** - Automated tournament execution using Challonge API
  - Pulls tournament brackets from Challonge
  - Uses computer vision to determine match winners
  - Posts results back to Challonge
  - Runs on Raspberry Pi

- **challonge** - Elixir wrapper for Challonge API
- **submission_info** - Tournament Submission App data handling
- **true_skill** - TrueSkill ranking algorithm implementation
- **rabbit_tools** - Utilities for working with RabbitMQ-based automations

## Development Commands

### Elixir Applications

Each app in `apps/` is independent. Navigate to the specific app directory to work on it:

```bash
cd apps/[app_name]

# Install dependencies
mix deps.get

# Run tests
mix test

# Run tests for a specific file
mix test test/path/to/test_file.exs

# Run a specific test by line number
mix test test/path/to/test_file.exs:42

# Format code (REQUIRED after changes per global rules)
mix format
```

### Firmware (Picopad)

See `firmware/picopad/CLAUDE.md` for complete firmware development instructions. Key commands:

```bash
# Build firmware (requires PICO_SDK_PATH environment variable)
cd firmware/picopad
./scripts/build.sh

# Run C tests
cd firmware/picopad/test
mkdir -p build && cd build
cmake .. && make
ctest --output-on-failure
```

### Notebooks

Livebook notebooks in `notebooks/` provide interactive workflows for:

- Tournament automation (`tournament_runner.livemd`)
- Rabbit Driver automations (`rabbit_driver.livemd`, `squad_strike.livemd`)
- Personality analysis (`personality.livemd`)
- Attribute heat maps (`attribute_heat_map.livemd`)

## Architecture & Dependencies

### Dependency Graph (Simplified)

```
tournament_runner → autopilot → vision (OpenCV)
                 → joycontrol
                 → challonge
                 → submission_info

autopilot → vision
         → joycontrol (optional)
         → luerl (Lua scripting)

rabbit_driver → autopilot
              → picopad
              → vision
              → amqp (RabbitMQ)

ssbu → amiibo_serialization

picopad (Elixir) → circuits_uart
```

### Path Dependencies

Applications use local path dependencies (e.g., `{:vision, path: "../vision"}`), not Hex packages. All dependencies must be available locally in the `apps/` directory.

### Computer Vision Stack

- **evision** - OpenCV bindings for Elixir
- Requires pre-compiled OpenCV binaries on Raspberry Pi (see `apps/vision/README.md`)
- Resolution-dependent templates (default: 640x480 from Genki Shadowcast)

### Controller Emulation

Two implementation approaches:
1. **Joycontrol** (Python) - Bluetooth HID emulation via Python wrapper
2. **Picopad** (C + Elixir) - Hardware-based emulation using Raspberry Pi Pico 2 W

## Testing Conventions

Tests follow AAA (Arrange, Act, Assert) pattern with comments separating sections:

```elixir
describe "function_name/arity" do
  test "description of behavior" do
    # Arrange
    input = setup_data()

    # Act
    result = MyModule.function_name(input)

    # Assert
    assert result == expected
  end
end
```

Use `describe` blocks to group related tests by function or feature.

## Important Notes

### Formatting

**CRITICAL**: Always run `mix format` after changing Elixir code. This is a hard requirement per global coding standards.

### No Interactive Commands

Never use `iex` in automated contexts - it's an interactive process that will hang. Use `mix test` or `mix run` for non-interactive execution.

### Hardware Context

Many apps are designed to run on Raspberry Pi hardware:

- Vision apps require USB capture cards
- Gamepad/Tournament Runner require Bluetooth pairing with Nintendo Switch
- Some apps require specific GPIO hardware (Joy Bonnet, AmmoBox)

### Releases

Some apps (e.g., `tournament_runner`) include Mix release configurations for deployment to Raspberry Pi.

## Related Documentation

- `firmware/picopad/CLAUDE.md` - Detailed firmware development guide
- `firmware/picopad/docs/` - Protocol specifications (Switch HID, NFC, host protocol)
- Individual `apps/*/README.md` - App-specific setup and usage instructions

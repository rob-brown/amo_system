# RabbitDriver

RabbitDriver is a tool for running automations on the Nintendo Switch. The main
example provided is running tournaments in Super Smash Bros. Ultimate.

The automations are driven by sending messages to a RabbitMQ broker. By default, it's
expected the RabbitMQ broker is running on the Raspberry Pi that is also running this
app.

The benefit of using RabbitMQ to drive the automation is that any programm language
that can talk to RabbitMQ can control the automation. Pretty much every programming
language has a RabbitMQ library (sometimes called AMQP). Though using Elixir can still be
advantageous since the automations can be run with a Livebook. Plus this repo contains many
libraries to help in building automations.

There is an
[example Livebook](https://github.com/rob-brown/amo_system/blob/rabbit-driver/notebooks/rabbit_driver.livemd)
that runs Squad Strike matches in SSBU.

## Topics

The messages are sent to a single topic exchange. The following topics and their
purposes are listed below.

| Topic                                              | Recipient | Description       |
|:---------------------------------------------------|:----------|:------------------|
| <a href="#image.list">image.list</a>               | App       | List all the known images. |
| <a href="#image.get">image.get</a>                 | App       | Get a specified image. |
| <a href="#image.put">image.put</a>                 | App       | Send an image to be stored for later use. |
| <a href="#image.delete">image.delete</a>           | App       | Delete a stored image. |
| <a href="#image.screenshot">image.screenshot</a>   | App       | Create a screenshot and return it. |
| <a href="#image.visible">image.visible</a>         | App       | Returns the bounding box of the specified image, if found. |
| <a href="#image.count">image.count</a>             | App       | Returns the number of images matching the given image. |
| <a href="#script.list">script.list</a>             | App       | List all the known scripts. |
| <a href="#script.get">script.get</a>               | App       | Get a specified script. |
| <a href="#script.put">script.put</a>               | App       | Send a script to be stored for later use. |
| <a href="#script.delete">script.delete</a>         | App       | Delete a stored script. |
| <a href="#script.run">script.run</a>               | App       | Run a specified script. |
| <a href="#log.level">log.[level]</a>               | Client    | Log messages for a particular level, ex. warning, error. |

## Payloads

The following sections include example messages. Where appplicable response
messages are included. All messages are in JSON format.

<h3 id="image.list">image.list</h3>

#### Message

```json
{}
```

#### Response

```json
{
  "images": [
    "ss_fp.png",
    "ss_kirby.png",
    "ss_squad_victory.png",
    "ss_pointer.png",
    "ss_team1_victory.png",
    "ss_team2_victory.png",
    "ss_cpu.png"
  ]
 }
```

<h3 id="image.get">image.get</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png"
}
```

#### Response

```json
{
  "image": {
    "name": "ss_squad_victory.png",
    "size": 2342,
    "bytes": "data:image/png;base64,...",
  }
}
```

<h3 id="image.put">image.put</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png",
  "bytes": "data:image/png;base64,..."
}
```

<h3 id="image.delete">image.delete</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png"
}
```

<h3 id="image.screenshot">image.screenshot</h3>

#### Message

```json
{
  "timeout_ms": 5000
}
```

#### Response

```json
{
  "screenshot": {
    "type": "image/png",
    "size": 424475,
    "bytes": "data:image/png;base64,...",
  }
}
```

<h3 id="image.visible">image.visible</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png",
  // Optional, default 0.8
  "confidence": 0.8
}
```

#### Response

```json
{
  "confidence": 0.8231834173202515,
  "error": null,
  "height": 480,
  "width": 640,
  "x1": 573,
  "x2": 592,
  "y1": 447,
  "y2": 466
}
```

<h3 id="image.count">image.count</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png"
  // Optional, default 0.89
  "confidence": 0.89
}
```

#### Response

```json
{
  "count": 0,
  "error": null
}
```

<h3 id="script.list">script.list</h3>

#### Message

```json
{}
```

#### Response

```json
{
  "scripts": [
    "ss_squad_start.lua",
    "ss_unload_amiibo.lua",
    "ss_after_match.lua",
    "ss_launch_ssbu.lua",
    "ss_screenshot.lua",
    "ss_close_game.lua",
    "ss_load_squad_strike.lua"
  ]
}
```

<h3 id="script.get">script.get</h3>

#### Message

```json
{
  "name": "ss_squad_victory.png"
}
```

#### Response

```json
{
  "image": {
    "name": "ss_squad_victory.png",
    "size": 2342,
    "bytes": "data:image/png;base64,...",
  }
}
```

<h3 id="script.put">script.put</h3>

#### Message

```json
{
  "name": "ss_launch_ssbu.lua",
  "bytes": "..."
}
```

<h3 id="script.delete">script.delete</h3>

#### Message

```json
{
  "name": "ss_launch_ssbu.lua",
}
```

<h3 id="script.run">script.run</h3>

#### Message

```json
{
  "name": "ss_launch_ssbu.lua",
  "timeout_ms": 60000
}
```

or

```json
{
  "raw": "press(\"a\")\npress(\"b\")",
  "timeout_ms": 2000
}
```

<h3 id="log.level">log.[level]</h3>

#### Message

```json
{
  "msg": "Something happened.",
  "timestamp": "2023-09-02T00:53:31.699Z",
  "level": "warn",
  "meta": {...}
}
```

## Initial Setup

See the common [OS Setup doc](../../docs/os-setup.markdown) for details to
install an OS for the Raspberry Pi.

## Joycontrol Installation

First, you will need to install
[Joycontrol and its dependencies](https://github.com/poohl/joycontrol).
This involves editing some system files too. You may need to run the
`run_controller_cli.py` script to pair your Nintendo Switch to your Raspberry Pi.

## OpenCV Installation

See the [Vision library](../vision/README.md) for details about installing OpenCV.

## USB Capture Card

See the [Vision library](../vision/README.md) for details about supported USB
capture cards.

## Rabbit Driver Installation

You probably have `curl` and `cron` already installed. This guide will also assume you
are installing RabbitMQ locally. You can install all 3 packages like this:

```bash
sudo apt update
sudo apt install curl cron rabbitmq-server --yes
```

You can install the app like this:

```bash
curl -fsSL https://raw.githubusercontent.com/rob-brown/amo_system/main/apps/rabbit_driver/install.sh | bash -s
```

> ⛔️ **WARNING:** You shouldn't just trust someone to run an arbitrary script on your
system, especially one that has root permissions like this one does. Take some
time and look over the script to ensure it's not doing anything nefarious. You
can also run the commands yourself to better see the effects.

Once you've installed the app, you will need to pair your Pi with your Nintendo
Switch. Then every time after your Pi boots, it will try to connect to your
Nintendo Switch.

## FAQ

<details>
  <summary><strong>Does this replace <a href="https://github.com/rob-brown/amo_system/tree/rabbit-driver/apps/tournament_runner">Tournament Runner</a>?</strong></summary><br/>

  <p>No, Tournament Runner is designed to run entirely on a Raspberry Pi. Rabbit Driver is instead reliant on another computer to run the main logic. Though you could install a Livebook server on the Pi which runs the automation. This retains the flexibility of Rabbit Driver but also runs entirely on the Pi.
  </p>
</details>

<details>
  <summary><strong>What languages can I use with Rabbit Driver?</strong></summary><br/>

  <p>The RabbitMQ website has <a href="https://www.rabbitmq.com/tutorials/tutorial-one-elixir.html">tutorials</a> for Python, Java, Spring, Ruby, PHP, C♯, Javascript, Go, Elixir, Objective-C, and Swift. Though these are not a complete list of languages that have a RabbitMQ library.
  </p>
</details>

<details>
  <summary><strong>What hardware is needed?</strong></summary><br/>

  <p>I recommend using a Raspberry Pi 3, 4, 400, or Zero 2 W. You can probably get older devices to work, but the computer vision code will be slower. Other harware (not Raspberry Pi) can work but may require modifications.
  </p>

  <p>You will also need a USB capture card. See the <a href="../vision/README.md">Vision library</a> for details about supported USB capture cards.
  </p>
</details>

<details>
  <summary><strong>Wait! Since Rabbit Driver isn't specific to SSBU, can I use it on a different game?</strong></summary><br/>

  <p>YES! You could make automations for Link's Awakening, Pokémon Brilliant Diamond, or any other game you want. Though I recommend only using it for 2D and 2.5D games. 3D games are much harder.
  </p>
</details>

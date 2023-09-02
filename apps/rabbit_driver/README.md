# RabbitDriver

RabbitDriver is a tool for running automations on the Nintendo Switch. The main
example provided is running tournaments in Super Smash Bros. Ultimate.

The automations are driven by sending messages to a RabbitMQ broker. By default, it's
expected the RabbitMQ broker is running on the Raspberry Pi that is also running this
app.

The benefit of using RabbitMQ to drive the automation is that any programm language
that can talk to RabbitMQ can control the automation. Pretty much every programming
language has a RabbitMQ (sometimes called AMQP) library. Though using Elixir can still be
advantageous since the automations can be run with a Livebook.

## Topics

The messages are sent to a single topic exchange. The following topics and their
purposes are listed below.

| Topic                                              | Recipient | Description       |
|:---------------------------------------------------|:----------|:------------------|
| <a href="#image.list">image.list</a>               | App       | List all the known images. |
| <a href="#image.get">image.get</a>                 | App       | Get a specified image. |
| <a href="#image.put">image.put</a>                 | App       | Send an image to be stored for later use. |
| <a href="#image.delete">image.delete</a>           | App       | Send an image to be stored for later use. |
| <a href="#image.screenshot">image.screenshot</a>   | App       | Create a screenshot and return it. |
| <a href="#image.visible">image.visible</a>         | App       | Returns the bounding box of the specified image, if found. |
| <a href="#image.count">image.count</a>             | App       | Returns the number of images matching the given image. |
| <a href="#script.list">script.list</a>             | App       | List all the known scripts. |
| <a href="#script.get">script.get</a>               | App       | Get a specified script. |
| <a href="#script.put">script.put</a>               | App       | Send a script to be stored for later use. |
| <a href="#script.delete">script.delete</a>         | App       | Send a script to be stored for later use. |
| <a href="#script.run">script.run</a>               | App       | Run a specified script. |
| <a href="#log.level">log.[level]</a>               | Client    | Log messages for a particular level, ex. warning, error. |
| <a href="#system.status">system.status</a>         | App       | Get the status of the system. |
| <a href="#system.heartbeat">system.heartbeat</a>   | App       | A regular message sent out to show the system is still running. |
| <a href="#bluetooth.pair">bluetooth.pair</a>       | App       | Pair to a Nintendo Switch. |
| <a href="#bluetooth.reset">bluetooth.reset</a>     | App       | Unpair from a Nintendo Switch. |
| <a href="#bluetooth.restart">bluetooth.restart</a> | App       | Restart the Bluetooth stack. |
| <a href="#bluetooth.status">bluetooth.status</a>   | App       | Get the status of the bluetooth stack. |

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
  "name": "ss_squad_victory.png"
}
```

#### Response

```json
{
  "confidence": 0.8231834173202515,
  "error": nil,
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
}
```

#### Response

```json
{
  "count": 0,
  "error": nil
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
  "raw": "press("a")\npress("b")",
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

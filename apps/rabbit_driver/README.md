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

| Topic             | Recipient | Description       |
|:------------------|:----------|:------------------|
| image.list        | App       | List all the known images. |
| image.get         | App       | Get a specified image. |
| image.put         | App       | Send an image to be stored for later use. |
| image.delete      | App       | Send an image to be stored for later use. |
| script.list       | App       | List all the known scripts. |
| script.get        | App       | Get a specified script. |
| script.put        | App       | Send a script to be stored for later use. |
| script.delete     | App       | Send a script to be stored for later use. |
| script.run        | App       | Run a specified script. |
| vision.screenshot | App       | Create a screenshot and return it. |
| log.[level]       | Client    | Log messages for a particular level, ex. warning, error. |
| log.enable        | App       | Enable log messages, enabled by default. |
| log.disable       | App       | Disable log messages, enabled by default. |
| system.configure  | App       | Configure the system options (TBD). |
| system.clear      | App       | Clear all queued commands. |
| system.status     | App       | Get the status of the system. |
| system.heartbeat  | App       | A regular message sent out to show the system is still running. |
| bluetooth.pair    | App       | Pair to a Nintendo Switch. |
| bluetooth.reset   | App       | Unpair from a Nintendo Switch. |
| bluetooth.restart | App       | Restart the Bluetooth stack. |
| bluetooth.status  | App       | Get the status of the bluetooth stack. |

## Payloads

The following are sample paylaods.

# Autopilot

This package is designed to make some automation tasks easier that involve both
`Joycontrol` and `Vision`.

Including this package will **not** automatically start the process for interacting
with the capture card.  Depending on your use case you many not want to start the
process when your application launches. When starting `Vision`, you should start it
in a supervision tree.  If you start it with your application, then it will look like
this:

```elixir
defmodule MyApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Vision,
      # Other processes here.
    ]

    # Should I use :one_for_all?
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Features

### Pointer tracking

By providing an image of your pointer (with no background elements), you can use
`Autopilot.Pointer` to move your pointer to specific parts of the screen. This is
useful for moving the pointer to small hitboxes. Note that this is tuned for a 640x480
screen resolution. It may need adjustments for other screen resolutions.

### Lua scripting

`Autopilot.LuaScript` is designed to make it easy to write simple and readable scripts
that work both with bluetooth and computer vision. For example, the following script
loads two amiibo into a 1v1 match in Super Smash Bros. Ultimate.

```lua
-- Press button to wake-up controller if needed.
press("a")
-- Move to P1 type selector.
press("down", "500ms")
wait("1s")
-- Load amiibo
load_amiibo_binary(amiibo1)
-- Advance to amiibo input.
press("a")
wait("200ms")
press("a")
-- Wait a bit to avoid getting the ready prompt too soon.
wait("2s")
-- Wait for amiibo to be read.
wait_until_found("ready_to_fight.png", "4s")
-- Load amiibo
clear_amiibo()
load_amiibo_binary(amiibo2)
-- Move to P2 type selector.
press("right", "950ms")
wait("1s")
-- Advance to amiibo input.
press("a")
-- Wait a bit to avoid getting the ready prompt too soon.
wait("2s")
-- Wait for amiibo to be read.
wait_until_found("ready_to_fight.png", "4s")
-- Start the match.
press("plus")
-- Clear the amiibo to avoid problems later.
clear_amiibo()
```

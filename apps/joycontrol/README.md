# Joycontrol

This package is a wrapper around [poohl/joycontrol](https://github.com/Poohl/joycontrol).

This code was written specifically to run on a Raspberry Pi. It may not work on other
platforms or with other bluetooth radios.

Including this package will **not** automatically start the process for interacting with bluetooth.
Depending on your use case you many not want to start the bluetooth process when your application launches.
When starting `Joycontrol`, you should start it in a supervision tree. It's common for the connection to be dropped.
By including `Joycontrol` in a supervision tree, it will automatically restart and reconnect for you.
If you start it with your application, then it will look like this:

```elixir
defmodule MyApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Joycontrol,
      # Other processes here.
    ]

    # Should I use :one_for_all?
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

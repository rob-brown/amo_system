# Vision

This package is designed to make automation via computer vision easy. It's designed
to work with the [Genki Shadowcast](https://www.genkithings.com/products/shadowcast).
Though other external capture cards may still work.

Including this package will **not** automatically start the process for interacting
with the capture card. Depending on your use case you many not want to start the
process when your application launches. When starting `Vision`, you should start it
in a supervision tree. If you start it with your application, then it will look like
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

Be aware that any images you use for tracking are resolution dependent. If you change
the capture card to be a different resolution, then you will need to update any images
you use.

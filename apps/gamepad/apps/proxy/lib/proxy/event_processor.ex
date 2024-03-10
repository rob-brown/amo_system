defmodule Proxy.EventProcessor do
  require Logger

  def process(type, code, value) when is_integer(type) and is_integer(code) and is_integer(value) do
    Logger.info("Event #{inspect({type, code, value})}")

    # TODO: Determine the button and send to input tracker.
  end
end

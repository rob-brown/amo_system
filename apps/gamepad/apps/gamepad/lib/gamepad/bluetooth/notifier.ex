defmodule Gamepad.Bluetooth.Notifier do

  @name __MODULE__
  @key :status
  @status_options [:connected, :disconnected, :connecting]

  def child_spec(arg) do
    %{
      id: @name,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link(_) do
    Registry.start_link(keys: :duplicate, name: @name)
  end

  def register(module, function) do
    Registry.register(@name, @key, {module, function})
  end

  def notify(status) when status in @status_options do
    Registry.dispatch(@name, @key, fn entries ->
      for {_pid, {module, function}} <- entries do
        apply(module, function, [status])
      end
    end)
  end
end

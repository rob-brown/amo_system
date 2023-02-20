defmodule Gamepad.Bluetooth do
  require Logger

  alias Gamepad.Joycontrol

  def paired_devices() do
    case System.cmd("sudo", ["bluetoothctl", "paired-devices"]) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&(&1 |> String.split(" ", parts: 3) |> Enum.drop(1) |> List.to_tuple()))
        |> then(&{:ok, &1})

      {output, code} ->
        Logger.error("List devices failed with #{code} #{output}")
        {:error, output}
    end
  end

  def unpair_all() do
    {:ok, devices} = paired_devices()

    for {mac, _name} <- devices do
      unpair(mac)
    end

    :ok
  end

  def pair_and_connect() do
    if Joycontrol.running?() do
      {:error, :running}
    else
      unpair_all()
      DynamicSupervisor.start_child(Gamepad.DynamicSupervisor, Joycontrol.child_spec([]))
    end
  end

  def reconnect(mac) do
    DynamicSupervisor.start_child(
      Gamepad.DynamicSupervisor,
      Joycontrol.child_spec(reconnect: mac)
    )
  end

  def disconnect() do
    case Joycontrol.pid() do
      pid when is_pid(pid) ->
        DynamicSupervisor.terminate_child(Gamepad.DynamicSupervisor, pid)

      _ ->
        {:error, :not_running}
    end
  end

  def unpair(mac) do
    case System.cmd("sudo", ["bluetoothctl", "remove", mac]) do
      {_output, 0} ->
        :ok

      {output, _code} ->
        {:error, output}
    end
  end

  def info() do
    case System.cmd("sudo", ["bluetoothctl", "show"]) do
      {output, 0} ->
        {:ok, output}

      {output, _code} ->
        {:error, output}
    end
  end
end

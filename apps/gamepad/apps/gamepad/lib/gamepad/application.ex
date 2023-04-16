defmodule Gamepad.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    platform = platform()

    Logger.info("Running Gamepad for platform '#{inspect(platform)}'")

    children =
      [
        Gamepad.Bluetooth.Notifier,
        Gamepad.InputTracker,
        {DynamicSupervisor, strategy: :one_for_one, name: Gamepad.DynamicSupervisor}
      ] ++ platform_children(platform)

    opts = [strategy: :one_for_one, name: Gamepad.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp platform() do
    case System.get_env("PLATFORM") do
      "joybonnet" ->
        :joybonnet

      "ammobox" ->
        :ammobox

      platform ->
        Logger.warn("Unknown platform '#{inspect(platform)}', defaulting to 'joybonnet'")
        :joybonnet
    end
  end

  defp platform_children(p = :ammobox) do
    [
      Gamepad.Lighting,
      button_task(p),
      pulse_lights(),
      lighting_task()
    ]
  end

  defp platform_children(p = :joybonnet) do
    [
      joystick_task(),
      button_task(p)
    ]
  end

  defp joystick_task() do
    %{
      id: JoystickControlTask,
      start: {Task, :start_link, [&listen_for_joystick/0]}
    }
  end

  defp listen_for_joystick() do
    Gamepad.Joystick.listen_forever()
  end

  defp button_task(platform) do
    %{
      id: ButtonControlTask,
      start: {Task, :start_link, [fn -> listen_for_buttons(platform) end]}
    }
  end

  defp listen_for_buttons(p) do
    Gamepad.Button.listen_forever(p)
  end

  defp lighting_task() do
    %{
      id: LightingTask,
      start: {Task, :start_link, [&update_lighting/0]}
    }
  end

  defp update_lighting() do
    Gamepad.Bluetooth.Notifier.register(__MODULE__, :update_lights)

    # Sleep forever so the subscription isn't removed.
    Process.sleep(:infinity)
  end

  def update_lighting(:connected) do
    Gamepad.Lighting.on()
  end

  def update_lighting(:disconnected) do
    Gamepad.Lighting.blink()
  end

  def update_lighting(:connecting) do
    Gamepad.Lighting.pulse()
  end

  defp pulse_lights() do
    %{
      id: PulseLightsTask,
      start: {Task, :start_link, [Gamepad.Lighting, :pulse, []]},
      restart: :temporary
    }
  end
end

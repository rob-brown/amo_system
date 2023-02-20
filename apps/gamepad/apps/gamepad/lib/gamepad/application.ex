defmodule Gamepad.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      button_task(),
      joystick_task(),
      Joycontrol,
    ]

    opts = [strategy: :one_for_one, name: Gamepad.Supervisor]
    Supervisor.start_link(children, opts)
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

  defp button_task() do
    %{
      id: ButtonControlTask,
      start: {Task, :start_link, [&listen_for_buttons/0]}
    }
  end

  defp listen_for_buttons() do
    Gamepad.Button.listen_forever()
  end
end

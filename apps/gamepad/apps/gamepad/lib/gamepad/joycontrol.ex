defmodule Gamepad.Joycontrol do
  use GenServer

  require Logger

  alias Gamepad.Lighting
  alias Gamepad.Bluetooth.Notifier

  @enforce_keys [:port]
  defstruct [:port]

  @name __MODULE__

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def running?() do
    pid() != nil
  end

  def pid() do
    GenServer.whereis(@name)
  end

  defdelegate command(command), to: __MODULE__, as: :raw_command

  def raw_command(command) when is_binary(command) or is_atom(command) do
    GenServer.cast(@name, {:command, "#{command}\r\n"})
  end

  def load_amiibo(data) do
    Logger.debug("Loading amiibo")
    encoded = Base.encode64(data)
    command = "nfc_raw #{encoded}\r\n"
    GenServer.cast(@name, {:command, command})
  end

  def clear_amiibo() do
    command = "nfc remove\r\n"
    GenServer.cast(@name, {:command, command})
  end

  ## GenServer

  def init(opts) do
    Notifier.notify(:connecting)
    Process.sleep(:timer.seconds(3))
    port = open_port(opts)
    Notifier.notify(:connected)

    {:ok, %__MODULE__{port: port}}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {GenServer, :start_link, [__MODULE__, List.wrap(opts), [name: @name]]}
    }
  end

  def handle_cast({:command, command}, state) do
    Port.command(state.port, command)
    {:noreply, state}
  end

  def handle_info({_port, {:data, data}}, state) do
    if should_log?(data) do
      Logger.debug("[JOYCONTROL] #{inspect(data)}")
    end

    if needs_restart?(data) do
      {:stop, :error, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    _ = Logger.debug("Vision exited normally")
    Notifier.notify(:disconnected)
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Vision exited: #{code}")
    Notifier.notify(:disconnected)
    {:stop, code, state}
  end

  def terminate(reason, state) do
    _ = Logger.warn("Joycontrol terminating because #{inspect(reason)}")
    Notifier.notify(:disconnected)
    Port.close(state.port)
  end

  ## Helpers

  # sudo env PYTHONPATH=/home/pi/amiibots/joycontrol python3 run_controller_cli.py PRO_CONTROLLER -r auto

  defp open_port(opts) do
    Port.open({:spawn_executable, executable()}, port_args(opts))
  end

  defp port_args(reconnect: true) do
    port_args(reconnect: "auto")
  end

  defp port_args(reconnect: mac) when is_binary(mac) do
    with python_path = Path.expand("~/joycontrol", __DIR__),
         args =
           [
             "env",
             "PYTHONPATH=#{python_path}",
             python3(),
             joycontrol_script(),
             "PRO_CONTROLLER",
             "-r",
             mac
           ]
           |> IO.inspect(label: "reconnect args") do
      [:use_stdio, :exit_status, :binary, :hide, :stderr_to_stdout, args: args]
    end
  end

  defp port_args(_opts) do
    with python_path = Path.expand("~/joycontrol", __DIR__),
         args =
           ["env", "PYTHONPATH=#{python_path}", python3(), joycontrol_script(), "PRO_CONTROLLER"]
           |> IO.inspect(label: "mac args") do
      [:use_stdio, :exit_status, :binary, :hide, :stderr_to_stdout, args: args]
    end
  end

  defp executable() do
    System.find_executable("sudo")
  end

  defp python3() do
    System.find_executable("python3")
  end

  defp joycontrol_script() do
    Path.expand("../../run_controller_cli.py", __DIR__) |> IO.inspect(label: "script path")
  end

  defp should_log?(data) do
    not Enum.any?(
      [
        "cmd >> "
        # "too slow!"
      ],
      &String.contains?(data, &1)
    )
  end

  defp needs_restart?(data) do
    text = to_string(data)

    Enum.any?(restart_reasons(), fn reason ->
      String.contains?(text, reason)
    end)
  end

  defp restart_reasons() do
    [
      "OSError: [Errno 107] Transport endpoint is not connected",
      "ConnectionRefusedError: [Errno 111] Connection refused"
    ]
  end
end

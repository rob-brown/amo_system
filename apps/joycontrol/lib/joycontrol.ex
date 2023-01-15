defmodule Joycontrol do
  use GenServer

  require Logger

  @enforce_keys [:port]
  defstruct [:port]

  @name __MODULE__

  defdelegate command(command), to: __MODULE__, as: :raw_command

  def raw_command(command) when is_binary(command) or is_atom(command) do
    GenServer.cast(@name, {:command, "#{command}\r\n"})
  end

  def load_amiibo(data) when is_binary(data) and byte_size(data) in [532, 540, 572] do
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

  def start_link(_) do
    GenServer.start_link(__MODULE__, [:ok], name: @name)
  end

  def init(_) do
    {:ok, %__MODULE__{port: open_port()}}
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [:ok]}
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
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Vision exited: #{code}")
    {:stop, code, state}
  end

  def terminate(reason, state) do
    _ = Logger.warn("Joycontrol terminating because #{inspect(reason)}")
    Port.close(state.port)
  end

  ## Helpers

  # sudo env PYTHONPATH=/home/pi/amiibots/joycontrol python3 run_controller_cli.py PRO_CONTROLLER -r auto

  defp open_port() do
    Port.open({:spawn_executable, executable()}, port_args())
  end

  defp port_args() do
    with python_path = Path.expand("../../joycontrol", __DIR__),
         args = [
           "env",
           "PYTHONPATH=#{python_path}",
           python3(),
           joycontrol_script(),
           "PRO_CONTROLLER",
           "-r",
           "auto"
         ] do
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
    Path.expand("../../run_controller_cli.py", __DIR__)
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

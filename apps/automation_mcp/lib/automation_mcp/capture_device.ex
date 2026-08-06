defmodule AutomationMCP.CaptureDevice do
  @moduledoc """
  Starts `Vision.Native` without letting a missing/unauthorized capture card
  take down the whole application. `Vision.Native.init/1` returns `{:stop,
  reason}` when the device can't be opened, which would otherwise fail the
  entire supervision tree since all initial children must start
  successfully. Opening it from `handle_continue/2` instead means this
  GenServer's own `init/1` always succeeds immediately, and the capture
  attempt happens afterward, off the boot path.

  The device is looked up by a priority-ordered list of name patterns (via
  `AutomationMCP.CaptureDeviceFinder`) rather than a fixed numeric index,
  since OpenCV's camera index reflects OS enumeration order, which shifts
  depending on what's plugged in, in what order, and even across replugs of
  the same device.
  """

  use GenServer

  require Logger

  alias AutomationMCP.CaptureDeviceFinder

  def start_link(name_patterns) do
    GenServer.start_link(__MODULE__, name_patterns, name: __MODULE__)
  end

  def available? do
    Process.whereis(Vision.Native) != nil
  end

  @doc """
  Runs `fun` and turns any exit caused by a missing/crashed capture device
  into `{:error, :capture_device_unavailable}` instead of crashing the
  caller.
  """
  def safe_call(fun) when is_function(fun, 0) do
    if available?() do
      fun.()
    else
      {:error, :capture_device_unavailable}
    end
  catch
    :exit, _reason -> {:error, :capture_device_unavailable}
  end

  @impl true
  def init(name_patterns) do
    {:ok, name_patterns, {:continue, :open_device}}
  end

  @impl true
  def handle_continue(:open_device, name_patterns) do
    with {:ok, index} <- CaptureDeviceFinder.find_index(name_patterns),
         {:ok, _pid} <- Vision.Native.start_link(index) do
      Logger.info("Capture device matching #{inspect(name_patterns)} opened at index #{index}")
    else
      {:error, reason} ->
        Logger.warning(
          "Could not open capture device matching #{inspect(name_patterns)}: #{inspect(reason)}. " <>
            "Screenshot and vision tools will report errors until this is resolved."
        )
    end

    {:noreply, name_patterns}
  end
end

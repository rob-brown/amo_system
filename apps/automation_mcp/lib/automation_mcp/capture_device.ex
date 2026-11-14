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

  def start_link({name_patterns, {_width, _height} = resolution}) do
    GenServer.start_link(__MODULE__, {name_patterns, resolution}, name: __MODULE__)
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

  @doc "Current actual capture resolution, as `{:ok, {width, height}}`."
  def resolution do
    safe_call(&Vision.Native.resolution/0)
  end

  @doc """
  Requests a new capture resolution. Not guaranteed to take effect — some
  capture cards only support a fixed set of modes. Returns the actual
  resulting resolution either way.
  """
  def set_resolution(width, height) do
    safe_call(fn -> Vision.Native.set_resolution(width, height) end)
  end

  @impl true
  def init({name_patterns, resolution}) do
    {:ok, {name_patterns, resolution}, {:continue, :open_device}}
  end

  @impl true
  def handle_continue(:open_device, {name_patterns, {width, height} = resolution}) do
    with {:ok, index} <- CaptureDeviceFinder.find_index(name_patterns),
         {:ok, _pid} <- Vision.Native.start_link({index, width, height}) do
      log_opened(name_patterns, index, resolution)
    else
      {:error, reason} ->
        Logger.warning(
          "Could not open capture device matching #{inspect(name_patterns)}: #{inspect(reason)}. " <>
            "Screenshot and vision tools will report errors until this is resolved."
        )
    end

    {:noreply, {name_patterns, resolution}}
  end

  defp log_opened(name_patterns, index, {width, height}) do
    case Vision.Native.resolution() do
      {:ok, {^width, ^height}} ->
        Logger.info(
          "Capture device matching #{inspect(name_patterns)} opened at index #{index} (#{width}x#{height})"
        )

      {:ok, {actual_width, actual_height}} ->
        Logger.warning(
          "Capture device matching #{inspect(name_patterns)} opened at index #{index}, but requested " <>
            "#{width}x#{height} and got #{actual_width}x#{actual_height} instead. " <>
            "The device may not support the requested resolution. Template images must match the actual resolution."
        )

      {:error, reason} ->
        Logger.info(
          "Capture device matching #{inspect(name_patterns)} opened at index #{index}, requested #{width}x#{height} " <>
            "(could not confirm actual resolution: #{inspect(reason)})"
        )
    end
  end
end

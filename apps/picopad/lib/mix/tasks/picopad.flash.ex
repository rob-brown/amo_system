defmodule Mix.Tasks.Picopad.Flash do
  @moduledoc """
  Builds the picopad firmware and flashes it over USB, with no BOOTSEL press.

      mix picopad.flash

  Requires a picopad already running firmware that understands the reset
  command (`Picopad.reset/2`). If the currently flashed firmware can't
  enumerate USB serial at all, this can't recover the board remotely - see
  firmware/picopad/docs/debug-probe-setup.md for that fallback.
  """
  use Mix.Task

  require Logger

  @shortdoc "Build and flash picopad firmware without pressing BOOTSEL"

  @firmware_dir Path.expand("../../../../../firmware/picopad", __DIR__)
  @build_script Path.join(@firmware_dir, "scripts/build.sh")
  @uf2_path Path.join(@firmware_dir, "build/switch_controller.uf2")
  @uf2_name "switch_controller.uf2"

  @mount_timeout_ms 10_000
  @reconnect_timeout_ms 15_000
  @poll_interval_ms 250

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Building firmware...")
    build!()

    Mix.shell().info("Looking for a connected picopad...")
    {pid, port} = connect!()

    Mix.shell().info("Rebooting #{port} into BOOTSEL mode...")
    Picopad.reset(pid, true)
    Picopad.disconnect(pid)

    Mix.shell().info("Waiting for mass-storage volume...")
    volume = wait_for_volume!()

    Mix.shell().info("Copying firmware to #{volume}...")
    File.cp!(@uf2_path, Path.join(volume, @uf2_name))

    Mix.shell().info("Waiting for picopad to come back online...")
    {_pid, port} = wait_for_reconnect!()

    Mix.shell().info("Flashed and reconnected on #{port}.")
  end

  defp build!() do
    case System.cmd("sh", [@build_script], cd: @firmware_dir, stderr_to_stdout: true) do
      {output, 0} ->
        unless File.exists?(@uf2_path) do
          Mix.raise("Build script exited 0 but #{@uf2_path} was not produced:\n#{output}")
        end

      {output, status} ->
        Mix.raise("Firmware build failed (exit #{status}):\n#{output}")
    end
  end

  defp connect!() do
    case discover_picopad() do
      {:ok, pid, port} -> {pid, port}
      :error -> Mix.raise("No picopad found on any serial port")
    end
  end

  defp discover_picopad() do
    candidate_ports()
    |> Enum.find_value(:error, fn port ->
      case attempt_connect(port) do
        {:ok, pid} -> {:ok, pid, port}
        :error -> false
      end
    end)
  end

  defp attempt_connect(port) do
    case Picopad.connect(port) do
      {:ok, pid} ->
        case safe_status(pid) do
          {:ok, _info} ->
            {:ok, pid}

          {:error, _reason} ->
            Picopad.disconnect(pid)
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  defp safe_status(pid) do
    Picopad.status(pid)
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp candidate_ports() do
    case Circuits.UART.enumerate() do
      ports when is_map(ports) ->
        ports
        |> Map.keys()
        |> Enum.reject(&String.contains?(&1, "Bluetooth"))
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp wait_for_volume!() do
    case poll_until(@mount_timeout_ms, &find_bootsel_volume/0) do
      {:ok, volume} -> volume
      :timeout -> Mix.raise("Timed out waiting for the picopad mass-storage volume to mount")
    end
  end

  defp find_bootsel_volume() do
    ["RPI-RP2", "RP2350"]
    |> Enum.map(&Path.join("/Volumes", &1))
    |> Enum.find(&File.dir?/1)
    |> case do
      nil -> nil
      volume -> {:ok, volume}
    end
  end

  defp wait_for_reconnect!() do
    case poll_until(@reconnect_timeout_ms, &discover_picopad_ok/0) do
      {:ok, result} ->
        result

      :timeout ->
        Mix.raise(
          "Timed out waiting for the picopad to reconnect after flashing. " <>
            "The new firmware may have crashed before enumerating USB serial - " <>
            "a manual BOOTSEL recovery may be needed " <>
            "(see firmware/picopad/docs/debug-probe-setup.md)."
        )
    end
  end

  defp discover_picopad_ok() do
    case discover_picopad() do
      {:ok, pid, port} -> {:ok, {pid, port}}
      :error -> nil
    end
  end

  defp poll_until(timeout_ms, fun) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_poll_until(deadline, fun)
  end

  defp do_poll_until(deadline, fun) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      _ ->
        if System.monotonic_time(:millisecond) >= deadline do
          :timeout
        else
          Process.sleep(@poll_interval_ms)
          do_poll_until(deadline, fun)
        end
    end
  end
end

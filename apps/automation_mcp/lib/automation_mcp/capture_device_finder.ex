defmodule AutomationMCP.CaptureDeviceFinder do
  @moduledoc """
  Resolves the OpenCV camera index for a device by matching its name against
  a priority-ordered list of patterns. Enumeration order (and therefore the
  numeric index OpenCV expects) shifts depending on what's plugged in, in
  what order, and even across replugs of the same device, so a hardcoded
  index isn't reliable — but the device's name is stable.
  """

  @doc """
  Finds the index of the first device matching any pattern in
  `name_patterns`, trying patterns in order (not enumeration order), so a
  higher-priority but not-yet-plugged-in device doesn't lose to a
  lower-priority one that happens to enumerate first.
  """
  def find_index(name_patterns) when is_list(name_patterns) do
    with {:ok, devices} <- list_devices() do
      name_patterns
      |> Enum.find_value({:error, :not_found}, fn pattern ->
        case Enum.find(devices, fn {_index, name} -> name_matches?(name, pattern) end) do
          {index, _name} -> {:ok, index}
          nil -> nil
        end
      end)
    end
  end

  def find_index(name_pattern) when is_binary(name_pattern) do
    find_index([name_pattern])
  end

  defp list_devices do
    case :os.type() do
      {:unix, :darwin} -> list_macos()
      {:unix, :linux} -> list_linux()
      other -> {:error, {:unsupported_platform, other}}
    end
  end

  defp list_macos do
    case System.find_executable("ffmpeg") do
      nil ->
        {:error, :ffmpeg_not_found}

      ffmpeg ->
        {output, _status} =
          System.cmd(ffmpeg, ~w(-f avfoundation -list_devices true -i ""), stderr_to_stdout: true)

        {:ok, parse_avfoundation(output)}
    end
  end

  @doc false
  def parse_avfoundation(output) do
    output
    |> String.split("\n")
    |> video_section()
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/\[(\d+)\] (.+)$/, line) do
        [_, index_str, name] -> [{String.to_integer(index_str), name}]
        _ -> []
      end
    end)
  end

  defp video_section(lines) do
    lines
    |> Enum.drop_while(&(not String.contains?(&1, "AVFoundation video devices")))
    |> Enum.take_while(&(not String.contains?(&1, "AVFoundation audio devices")))
  end

  defp list_linux do
    devices =
      "/sys/class/video4linux/video*/name"
      |> Path.wildcard()
      |> Enum.map(fn name_file ->
        name = name_file |> File.read!() |> String.trim()

        index =
          name_file
          |> Path.dirname()
          |> Path.basename()
          |> String.trim_leading("video")
          |> String.to_integer()

        {index, name}
      end)

    {:ok, devices}
  end

  defp name_matches?(name, pattern) do
    String.contains?(String.downcase(name), String.downcase(pattern))
  end
end

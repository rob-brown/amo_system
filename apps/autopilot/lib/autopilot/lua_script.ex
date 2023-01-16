defmodule Autopilot.LuaScript do
  @moduledoc """
  A module capable of running automated scripts using bluetooth and computer vision.
  See the private functions for details of each of the functions.
  """

  @doc """
  Reads the given Lua script file and exectutes it. May be given bindings to pass data into the script.
  """
  def run_file(path, opts \\ []) do
    cwd = path |> Path.expand() |> Path.basename()
    opts = Keyword.put_new(opts, :cwd, cwd)

    path
    |> Path.expand()
    |> File.read!()
    |> run_string(opts)
  end

  @doc """
  Interprets the given string as a Lua script. May be given bindings to pass data into the script.
  """
  def run_string(code, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())

    :luerl_sandbox.init()
    |> add_bindings(Keyword.get(opts, :bindings, []))
    |> add_function("load_amiibo_file", load_amiibo_file(cwd))
    |> add_function("load_amiibo_binary", &load_amiibo_binary/2)
    |> add_function("clear_amiibo", &clear_amiibo/2)
    |> add_function("move_pointer", move_pointer(cwd))
    |> add_function("wait", &wait/2)
    |> add_function("wait_until_found", wait_until_found(cwd))
    |> add_function("wait_until_gone", wait_until_gone(cwd))
    |> add_function("capture", capture(cwd))
    |> add_function("capture_crop", capture_crop(cwd))
    |> add_function("joycontrol", &joycontrol/2)
    |> add_function("press", &press/2)
    |> add_function("is_visible", is_visible(cwd))
    |> add_function("count", count(cwd))
    |> add_function("count_crop", count_crop(cwd))
    |> run(code)
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, _lua_state} ->
        :ok
    end
  end

  ## Helpers

  defguardp is_button(b)
            when is_bitstring(b) and
                   b in ~w(a b x y down left right up minus plus r zr l zl home capture r_stick l_stick)

  defguardp is_amiibo_bin(b) when is_bitstring(b) and byte_size(b) in [532, 540, 572]

  defp add_bindings(state, []) do
    state
  end

  defp add_bindings(state, [{key, value} | rest]) do
    key
    |> to_string()
    |> List.wrap()
    |> :luerl.set_table(value, state)
    |> add_bindings(rest)
  end

  defp add_function(state, path, function) when is_binary(path) and is_function(function, 2) do
    :luerl.set_table([path], function, state)
  end

  # Automation scripts can take long so the script is given
  # Unlimited time and reductions.
  defp run(state, code) do
    case :luerl_sandbox.run(code, state, 0, [], :infinity) do
      {:error, e} -> {:error, e}
      {_result, new_state} -> {:ok, new_state}
    end
  end

  # Expects a file path (relative or absolute) to an amiibo bin file.
  defp load_amiibo_file(cwd) do
    fn [path | _], lua_state ->
      binary = path |> Path.expand(cwd) |> File.read!()
      Joycontrol.load_amiibo(binary)
      {[], lua_state}
    end
  end

  # Expects a raw amiibo bin data. Must be 532, 540, or 572 bytes.
  defp load_amiibo_binary([binary | _], lua_state) when is_amiibo_bin(binary) do
    Joycontrol.load_amiibo(binary)
    {[], lua_state}
  end

  # No args. Clears the previously loaded amiibo.
  defp clear_amiibo(_, lua_state) do
    Joycontrol.clear_amiibo()
    {[], lua_state}
  end

  # Expects a path to an existing image file used to find the pointer.
  # Also takes to {x, y} coordinates. The first is the top-left corner.
  # The second is the bottom-left corner.
  # Lua example:
  #   move_pointer("targets/pointer.png", {100, 200}, {150, 2050})
  defp move_pointer(cwd) do
    fn [target, [{1, x1}, {2, y1}], [{1, x2}, {2, y2}] | _], lua_state ->
      target = Path.expand(target, cwd)
      Autopilot.Pointer.move({x1..x2, y1..y2}, target)
      {[], lua_state}
    end
  end

  # Expects a duration, either an integer representing milliseconds,
  # or a string with a "s" or "ms" suffix to indicate time unit.
  # Lua examples:
  #   wait("1200ms")
  #   wait("3s")
  #   wait(500)
  defp wait([duration | _], lua_state) do
    duration = parse_duration(duration)
    Process.sleep(duration)
    {[], lua_state}
  end

  # Expects a path to an image file. Waits until the image appears,
  # or the timeout elapses. Returns true if the image is visible.
  defp wait_until_found(cwd) do
    fn [target, timeout | _], lua_state when is_binary(target) and is_number(timeout) ->
      target = Path.expand(target, cwd)

      case Vision.wait_until_found(target, timeout) do
        {:ok, nil} ->
          {[false], lua_state}

        {:ok, _} ->
          {[true], lua_state}

        _ ->
          {[false], lua_state}
      end
    end
  end

  # Expects a path to an image file. Waits until the image appears,
  # or the timeout elapses. Returns true if the image is **not** visible.
  defp wait_until_gone(cwd) do
    fn [target, timeout | _], lua_state when is_binary(target) and is_number(timeout) ->
      target = Path.expand(target, cwd)

      case Vision.wait_until_gone(target, timeout) do
        {:ok, nil} ->
          {[true], lua_state}

        {:ok, _} ->
          {[false], lua_state}

        _ ->
          {[false], lua_state}
      end
    end
  end

  # Takes a screenshot and saves to the given file path.
  defp capture(cwd) do
    fn [save_path | _], lua_state when is_binary(save_path) ->
      save_path = Path.expand(save_path, cwd)
      Vision.capture(save_path)
      {[], lua_state}
    end
  end

  # Takes a screenshot, crops it, and saves to the given file path.
  # Takes two {x, y} coordinates for the crop. The first is the
  # top-left corner. The other is the bottom-left corner.
  defp capture_crop(cwd) do
    fn [save_path, [{1, x1}, {2, y1}], [{1, x2}, {2, y2}] | _], lua_state
       when is_binary(save_path) and is_number(x1) and is_number(x2) and is_number(y1) and
              is_number(y2) ->
      save_path = Path.expand(save_path, cwd)
      Vision.capture_crop(save_path, {y1, x1}, {y2, x2})
      {[], lua_state}
    end
  end

  # Sends an arbitrary command to Joycontrol with the given string.
  defp joycontrol([command | _], lua_state) when is_binary(command) do
    Joycontrol.command(command)
    {[], lua_state}
  end

  # Presses a single button for the given duration in milliseconds.
  # If no duration, then defaults to 100 ms.
  # Lua example:
  #   press("b", 2000)
  defp press([button, duration | _], lua_state) when is_button(button) do
    duration = parse_duration(duration)
    Joycontrol.command("press #{button} #{duration}")
    {[], lua_state}
  end

  defp press([button], lua_state) do
    press([button, 100], lua_state)
  end

  # Returns true if the given image file is visible.
  defp is_visible(cwd) do
    fn [target | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)

      case Vision.visible(target) do
        {:ok, nil} ->
          {[false], lua_state}

        {:ok, _} ->
          {[true], lua_state}

        _ ->
          {[false], lua_state}
      end
    end
  end

  # Returns the number of times the given image file is visible.
  defp count(cwd) do
    fn [target | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)

      case Vision.count(target) do
        {:ok, n} ->
          {[n], lua_state}

        _ ->
          {[0], lua_state}
      end
    end
  end

  # Returns the number of times the given image file is visible.
  # The crop is given as two {x, y} coordinates. The first is the
  # top-left corner. The other is the bottom left corner.
  defp count_crop(cwd) do
    fn [target, [{1, x1}, {2, y1}], [{1, x2}, {2, y2}] | _], lua_state
       when is_binary(target) and is_number(x1) and is_number(x2) and is_number(y1) and
              is_number(y2) ->
      target = Path.expand(target, cwd)

      case Vision.count_crop(target, %{top: y1, left: x1, bottom: y2, right: x2}) do
        {:ok, n} ->
          {[n], lua_state}

        _ ->
          {[0], lua_state}
      end
    end
  end

  @doc """
  Parses the duration into milliseconds. Assumes milliseconds
  when no unit present. Decimal points are not allowed.

  Examples:

      iex> Autopilot.LuaScript.parse_duration("1000ms")
      1000

      iex> Autopilot.LuaScript.parse_duration("10s")
      10000

      iex> Autopilot.LuaScript.parse_duration("500")
      500

      iex> Autopilot.LuaScript.parse_duration(1500)
      1500
  """
  def parse_duration(duration) when is_binary(duration) do
    cond do
      String.ends_with?(duration, "ms") ->
        duration
        |> String.trim_trailing("ms")
        |> String.to_integer()

      String.ends_with?(duration, "s") ->
        duration
        |> String.trim_trailing("s")
        |> String.to_integer()
        |> Kernel.*(1000)

      true ->
        String.to_integer(duration)
    end
  end

  def parse_duration(duration) when is_integer(duration) do
    duration
  end
end

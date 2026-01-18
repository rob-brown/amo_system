defmodule Autopilot.LuaScript do
  @moduledoc """
  A module capable of running automated scripts using bluetooth and computer vision.
  See the private functions for details of each of the functions.
  """

  require Logger

  @doc """
  Reads the given Lua script file and exectutes it. May be given bindings to pass data into the script.
  """
  def run_file(path, opts \\ []) do
    cwd = path |> Path.expand() |> Path.dirname()
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

  defp add_bindings(state, []) do
    state
  end

  defp add_bindings(state, [{key, value} | rest]) do
    key
    |> to_string()
    |> List.wrap()
    |> :luerl.set_table_keys(value, state)
    |> case do
      {:ok, new_state} ->
        add_bindings(new_state, rest)

      error ->
        Logger.error("Failed to add binding '#{key}' #{inspect(error)}")
        state
    end
  end

  defp add_function(state, path, function) when is_binary(path) and is_function(function, 2) do
    {encoded_func, state} = :luerl.encode(function, state)

    case :luerl.set_table_keys([path], encoded_func, state) do
      {:ok, new_state} ->
        new_state

      error ->
        Logger.error("Failed to add function '#{path}' #{inspect(error)}")
        state
    end
  end

  # Automation scripts can take long so the script is given
  # Unlimited time and reductions.
  defp run(state, code) do
    opts = [max_time: :infinity, max_reductions: :none, spawn_opts: []]

    case :luerl_sandbox.run(code, opts, state) do
      {:ok, _result, new_state} -> {:ok, new_state}
      {:error, e} -> {:error, e}
      other -> {:error, other}
    end
  end

  # Expects a file path (relative or absolute) to an amiibo bin file.
  defp load_amiibo_file(cwd) do
    fn [path | _], lua_state ->
      path = Path.expand(path, cwd)

      debug_log("Loading amiibo from #{path}")

      binary = File.read!(path)
      gamepad_module().load_amiibo(binary)
      {[], lua_state}
    end
  end

  # Expects a raw amiibo bin data. Must be 532, 540, or 572 bytes.
  defp load_amiibo_binary([binary | _], lua_state) do
    debug_log("Loading amiibo #{byte_size(binary)} bytes")

    gamepad_module().load_amiibo(binary)

    {[], lua_state}
  end

  # No args. Clears the previously loaded amiibo.
  defp clear_amiibo(_, lua_state) do
    debug_log("Unloading amiibo")

    gamepad_module().clear_amiibo()
    {[], lua_state}
  end

  # Expects a path to an existing image file used to find the pointer.
  # Also takes to {x, y} coordinates. The first is the top-left corner.
  # The second is the bottom-left corner.
  # Lua example:
  #   move_pointer("targets/pointer.png", {100, 200}, {150, 2050})
  defp move_pointer(cwd) do
    fn args, lua_state ->
      case :luerl.decode_list(args, lua_state) do
        [target, coord1, coord2 | _] ->
          {x1, y1} = table_to_tuple(coord1)
          {x2, y2} = table_to_tuple(coord2)
          debug_log("Moving pointer to (#{x1}, #{y1}) (#{x2}, #{y2})")

          target = Path.expand(target, cwd)
          Autopilot.Pointer.move({x1..x2, y1..y2}, target)

        decoded_args ->
          Logger.error("move_pointer: unexpected args #{inspect(decoded_args)}")
      end

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

    debug_log("Waiting #{duration}")

    Process.sleep(duration)
    {[], lua_state}
  end

  # Expects a path to an image file. Waits until the image appears,
  # or the timeout elapses. Returns true if the image is visible.
  defp wait_until_found(cwd) do
    fn [target, timeout | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)
      timeout = parse_duration(timeout)

      debug_fun("Waiting until found #{target}", fn ->
        case Vision.Native.wait_until_found(target, timeout) do
          {:ok, nil} ->
            {[false], lua_state}

          {:ok, _} ->
            {[true], lua_state}

          _ ->
            {[false], lua_state}
        end
      end)
    end
  end

  # Expects a path to an image file. Waits until the image appears,
  # or the timeout elapses. Returns true if the image is **not** visible.
  defp wait_until_gone(cwd) do
    fn [target, timeout | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)
      timeout = parse_duration(timeout)

      debug_fun("Waiting until gone #{target}", fn ->
        case Vision.Native.wait_until_gone(target, timeout) do
          {:ok, nil} ->
            {[true], lua_state}

          {:ok, _} ->
            {[false], lua_state}

          _ ->
            {[false], lua_state}
        end
      end)
    end
  end

  # Takes a screenshot and saves to the given file path.
  defp capture(cwd) do
    fn [save_path | _], lua_state when is_binary(save_path) ->
      save_path = Path.expand(save_path, cwd)

      debug_log("Capturing to #{save_path}")

      Vision.Native.capture(save_path)
      {[], lua_state}
    end
  end

  # Takes a screenshot, crops it, and saves to the given file path.
  # Takes two {x, y} coordinates for the crop. The first is the
  # top-left corner. The other is the bottom-left corner.
  defp capture_crop(cwd) do
    fn args, lua_state ->
      case :luerl.decode_list(args, lua_state) do
        [save_path, coord1, coord2 | _] ->
          {x1, y1} = table_to_tuple(coord1)
          {x2, y2} = table_to_tuple(coord2)
          save_path = Path.expand(save_path, cwd)

          debug_log("Capturing crop to #{save_path}")

          Vision.Native.capture_crop(save_path, {y1, x1}, {y2, x2})
          {[], lua_state}
      end
    end
  end

  # Presses a single button for the given duration in milliseconds.
  # If no duration, then defaults to 100 ms.
  # Lua example:
  #   press("b", 2000)
  defp press([button, duration | _], lua_state) when is_button(button) do
    duration = parse_duration(duration)

    debug_log("Pressing #{button} #{duration}")

    gamepad_module().press(button, duration)
    Process.sleep(duration)
    {[], lua_state}
  end

  defp press([button], lua_state) do
    press([button, 100], lua_state)
  end

  # Returns true if the given image file is visible.
  defp is_visible(cwd) do
    fn [target | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)

      debug_fun("Looking for #{target}", fn ->
        case Vision.Native.visible(target) do
          {:ok, nil} ->
            {[false], lua_state}

          {:ok, _} ->
            {[true], lua_state}

          _ ->
            {[false], lua_state}
        end
      end)
    end
  end

  # Returns the number of times the given image file is visible.
  defp count(cwd) do
    fn [target | _], lua_state when is_binary(target) ->
      target = Path.expand(target, cwd)

      debug_fun("Counting #{target}", fn ->
        case Vision.Native.count(target) do
          {:ok, n} ->
            {[n], lua_state}

          _ ->
            {[0], lua_state}
        end
      end)
    end
  end

  # Returns the number of times the given image file is visible.
  # The crop is given as two {x, y} coordinates. The first is the
  # top-left corner. The other is the bottom left corner.
  defp count_crop(cwd) do
    fn args, lua_state ->
      case :luerl.decode_list(args, lua_state) do
        [target, coord1, coord2 | _] ->
          {x1, y1} = table_to_tuple(coord1)
          {x2, y2} = table_to_tuple(coord2)

          target = Path.expand(target, cwd)

          debug_fun("Counting cropped #{target}", fn ->
            case Vision.Native.count_crop(target, %{top: y1, left: x1, bottom: y2, right: x2}) do
              {:ok, n} ->
                {[n], lua_state}

              _ ->
                {[0], lua_state}
            end
          end)
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

  defp debug?() do
    Application.get_env(:autopilot, :debug) == true
  end

  defp debug_log(msg) do
    if debug?() do
      Logger.debug(msg)
    end
  end

  defp debug_fun(msg, fun) when is_function(fun, 0) do
    debug_log(msg)

    result = fun.()

    if debug?() do
      Logger.debug(inspect(result))
    end

    result
  end

  defp gamepad_module() do
    Application.get_env(:autopilot, :gamepad_module, Joycontrol)
  end

  defp table_to_tuple([{1, a}, {2, b}]) do
    {a, b}
  end
end

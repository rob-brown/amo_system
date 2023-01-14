defmodule AmiiboAutomation.LuaScript do
  def run_file(path) do
    path
    |> Path.expand()
    |> File.read!()
    |> run_string()
  end

  def run_string(code) do
    Sandbox.init()
    |> Sandbox.let_elixir_play!("sleep", &sleep/2)
    |> Sandbox.let_elixir_play!("wait_until_found", &wait_until_found/2)
    |> Sandbox.let_elixir_play!("wait_until_gone", &wait_until_gone/2)
    |> Sandbox.let_elixir_play!("capture", &capture/2)
    |> Sandbox.let_elixir_play!("capture_crop", &capture_crop/2)
    |> Sandbox.let_elixir_play!("press", &press/2)
    |> Sandbox.let_elixir_eval!("visible", &visible/2)
    |> Sandbox.let_elixir_eval!("count", &count/2)
    |> Sandbox.let_elixir_eval!("count_crop", &count_crop/2)
    |> Sandbox.play(code)
  end

  ## Helpers

  defp sleep(lua_state, [duration | _]) when is_number(duration) do
    Process.sleep(duration)
    lua_state
  end

  defp wait_until_found(lua_state, [target, timeout | _])
       when is_binary(target) and is_number(timeout) do
    Vision.wait_until_found(target, timeout)
    lua_state
  end

  defp wait_until_gone(lua_state, [target, timeout | _])
       when is_binary(target) and is_number(timeout) do
    Vision.wait_until_gone(target, timeout)
    lua_state
  end

  defp capture(lua_state, [save_path | _]) when is_binary(save_path) do
    Vision.capture(save_path)
    lua_state
  end

  defp capture_crop(lua_state, [save_path, top, left, bottom, right | _])
       when is_binary(save_path) and is_number(top) and is_number(left) and is_number(bottom) and
              is_number(right) do
    Vision.capture_crop(save_path, {top, left}, {bottom, right})
    lua_state
  end

  defp press(lua_state, [button, duration | _]) when is_binary(button) and is_number(duration) do
    Joycontrol.command("press #{button} #{duration}")
    lua_state
  end

  defp visible(_lua_state, [target | _]) when is_binary(target) do
    Vision.visible(target)
  end

  defp count(_lua_state, [target | _]) when is_binary(target) do
    Vision.count(target)
  end

  defp count_crop(_lua_state, [target, top, left, bottom, right | _])
       when is_binary(target) and is_number(top) and is_number(left) and is_number(bottom) and
              is_number(right) do
    Vision.count_crop(target, %{top: top, left: left, bottom: bottom, right: right})
  end
end

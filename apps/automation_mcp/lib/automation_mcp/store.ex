defmodule AutomationMCP.Store do
  @moduledoc """
  File-based storage for Lua scripts, template images, and screenshots.
  Mirrors the directory conventions used by `RabbitDriver.ScriptConsumer`
  and `RabbitDriver.ImageConsumer`.
  """

  def script_dir, do: Path.join(System.tmp_dir(), "automation-mcp-scripts")
  def image_dir, do: Path.join(System.tmp_dir(), "automation-mcp-images")
  def screenshot_dir, do: Path.join(System.tmp_dir(), "automation-mcp-screenshots")

  def ensure_dirs! do
    File.mkdir_p!(script_dir())
    File.mkdir_p!(image_dir())
    File.mkdir_p!(screenshot_dir())
  end

  def list_scripts, do: File.ls!(script_dir())
  def list_images, do: File.ls!(image_dir())

  def script_path(name), do: safe_path(script_dir(), name, ".lua")
  def image_path(name), do: safe_path(image_dir(), name, ".png")

  def lookup_script(name), do: lookup(script_path(name))
  def lookup_image(name), do: lookup(image_path(name))

  defp lookup(path) do
    if File.regular?(path) do
      {:ok, path}
    else
      {:error, "Not found"}
    end
  end

  def screenshot_path do
    name = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower) <> ".png"
    Path.join(screenshot_dir(), name)
  end

  def cleanup_later(path) do
    Task.start(fn ->
      Process.sleep(:timer.seconds(5))
      File.rm(path)
    end)
  end

  defp safe_path(_dir, <<c::utf8, _rest::binary>>, _ext) when c in [?~, ?., ?/] do
    raise ArgumentError, "Unsafe file name"
  end

  defp safe_path(dir, name, ext) do
    name = if String.ends_with?(name, ext), do: name, else: name <> ext
    Path.join(dir, name)
  end
end

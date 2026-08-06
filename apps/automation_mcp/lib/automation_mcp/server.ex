defmodule AutomationMCP.Server do
  @moduledoc """
  MCP server exposing Picopad-driven Nintendo Switch automation: button
  input, amiibo emulation, screenshots, vision checks, and Lua scripting.
  """

  use Anubis.Server,
    name: "amo-automation",
    version: "0.1.0",
    capabilities: [:tools]

  alias AutomationMCP.Tools

  component(Tools.PressButton)
  component(Tools.HoldButtons)
  component(Tools.ReleaseButtons)
  component(Tools.ReleaseAllButtons)
  component(Tools.SetStick)

  component(Tools.LoadAmiibo)
  component(Tools.ClearAmiibo)
  component(Tools.AmiiboStatus)

  component(Tools.ConnectionStatus)
  component(Tools.Reconnect)

  component(Tools.TakeScreenshot)
  component(Tools.SaveScreenshot)
  component(Tools.GetResolution)
  component(Tools.SetResolution)
  component(Tools.ListImages)
  component(Tools.GetImage)
  component(Tools.PutImage)
  component(Tools.DeleteImage)
  component(Tools.ImageVisible)
  component(Tools.CountImage)

  component(Tools.ListScripts)
  component(Tools.GetScript)
  component(Tools.PutScript)
  component(Tools.DeleteScript)
  component(Tools.RunScript)

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end

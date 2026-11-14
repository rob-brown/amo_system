defmodule PicopadProxy.AmiiboImage do
  @base_url "https://raw.githubusercontent.com/8bitDream/AmiiboAPI/dev/images"

  def url({head, tail}) do
    "#{@base_url}/icon_#{head}-#{tail}.png"
  end
end

defmodule KAR do
  alias AmiiboSerialization.Amiibo
  alias AmiiboSerialization.AppID

  def registered?(amiibo = %Amiibo{}) do
    Amiibo.format(amiibo) == :v3 and Amiibo.app_id(amiibo) == AppID.kar()
  end
end

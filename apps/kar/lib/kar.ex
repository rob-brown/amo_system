defmodule KAR do
  alias AmiiboSerialization.Amiibo
  alias AmiiboSerialization.AppID
  alias KAR.Machine

  def registered?(amiibo = %Amiibo{}) do
    Amiibo.format(amiibo) == :v3 and Amiibo.app_id(amiibo) == AppID.kar()
  end

  def machine(amiibo = %Amiibo{}) do
    Machine.read(amiibo)
  end

  def set_machine(amiibo = %Amiibo{}, source = %Amiibo{}) do
    with {:ok, machine} <- Machine.read(source) do
      set_machine(amiibo, machine)
    end
  end

  def set_machine(amiibo = %Amiibo{}, machine = %Machine{}) do
    Machine.write(amiibo, machine)
  end
end

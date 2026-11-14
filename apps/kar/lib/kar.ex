defmodule KAR do
  alias AmiiboSerialization.Amiibo
  alias AmiiboSerialization.AppID
  alias KAR.Machine
  alias KAR.Machines

  def registered?(amiibo = %Amiibo{}) do
    Amiibo.format(amiibo) == :v3 and Amiibo.app_id(amiibo) == AppID.kar()
  end

  def machines do
    Machines.names()
  end

  def machine(amiibo = %Amiibo{}) do
    Machine.read(amiibo)
  end

  def set_machine(amiibo = %Amiibo{}, machine) do
    with {:ok, machine} <- Machine.resolve(machine) do
      Machine.write(amiibo, machine)
    end
  end
end

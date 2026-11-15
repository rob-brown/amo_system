defmodule KAR.Riders do
  alias AmiiboSerialization.Amiibo

  @riders %{
    <<0x1F, 0x00, 0x00, 0x00>> => %{name: :kirby, default_machine: :warp_star},
    <<0x1F, 0x00, 0x01, 0x00>> => %{name: :sword_kirby, default_machine: :dragoon},
    <<0x1F, 0x01, 0x00, 0x00>> => %{name: :meta_knight, default_machine: :shadow_star},
    <<0x1F, 0x02, 0x00, 0x00>> => %{name: :king_dedede, default_machine: :tank_star},
    <<0x1F, 0x02, 0x01, 0x00>> => %{name: :noir_dedede, default_machine: :hydra},
    <<0x1F, 0x03, 0x01, 0x00>> => %{name: :waddle_dee, default_machine: :wing_star},
    <<0x1F, 0x04, 0x00, 0x00>> => %{name: :kawasaki, default_machine: :hop_star}
  }

  def names do
    @riders |> Map.values() |> Enum.map(& &1.name) |> Enum.sort()
  end

  def read(%Amiibo{} = amiibo) do
    <<head::binary-size(4), _::binary>> = Amiibo.amiibo_id(amiibo)

    case Map.fetch(@riders, head) do
      {:ok, rider} -> {:ok, rider}
      :error -> {:error, :unknown_rider}
    end
  end
end

defmodule AutomationMCP.Tools.Buttons do
  @moduledoc false

  @valid ~w(a b x y up down left right l r zl zr minus plus home capture l_stick r_stick)

  def valid, do: @valid

  def to_atoms(buttons) do
    case Enum.split_with(buttons, &(&1 in @valid)) do
      {_valid, []} -> {:ok, Enum.map(buttons, &String.to_existing_atom/1)}
      {_valid, invalid} -> {:error, "Unknown button(s): #{Enum.join(invalid, ", ")}"}
    end
  end
end

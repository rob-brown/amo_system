defmodule AutomationMCP.Tools.ButtonsTest do
  use ExUnit.Case, async: true

  alias AutomationMCP.Tools.Buttons

  describe "to_atoms/1" do
    test "converts known button names to atoms" do
      # Arrange
      buttons = ["a", "zr", "l_stick"]

      # Act
      result = Buttons.to_atoms(buttons)

      # Assert
      assert result == {:ok, [:a, :zr, :l_stick]}
    end

    test "rejects unknown button names" do
      # Arrange
      buttons = ["a", "banana"]

      # Act
      {:error, message} = Buttons.to_atoms(buttons)

      # Assert
      assert message =~ "banana"
    end
  end
end

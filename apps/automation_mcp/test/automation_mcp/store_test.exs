defmodule AutomationMCP.StoreTest do
  use ExUnit.Case, async: true

  alias AutomationMCP.Store

  describe "script_path/1" do
    test "appends the .lua extension when missing" do
      # Arrange
      name = "my_script"

      # Act
      path = Store.script_path(name)

      # Assert
      assert Path.basename(path) == "my_script.lua"
    end

    test "does not double the extension when already present" do
      # Arrange
      name = "my_script.lua"

      # Act
      path = Store.script_path(name)

      # Assert
      assert Path.basename(path) == "my_script.lua"
    end

    test "rejects path traversal attempts" do
      # Arrange
      name = "../../etc/passwd"

      # Act & Assert
      assert_raise ArgumentError, fn -> Store.script_path(name) end
    end
  end

  describe "lookup_script/1" do
    test "returns an error when the script does not exist" do
      # Arrange
      Store.ensure_dirs!()

      # Act
      result = Store.lookup_script("does_not_exist")

      # Assert
      assert result == {:error, "Not found"}
    end
  end
end

defmodule AutomationMCP.Tools.ReadAmiiboTest do
  use ExUnit.Case, async: true

  alias AutomationMCP.Tools.ReadAmiibo

  @moduletag :tmp_dir

  describe "validate_path/1" do
    test "accepts an absolute path" do
      # Arrange
      path = "/tmp/dump.bin"

      # Act
      result = ReadAmiibo.validate_path(path)

      # Assert
      assert result == :ok
    end

    test "rejects a relative path" do
      # Arrange
      path = "dump.bin"

      # Act
      {:error, message} = ReadAmiibo.validate_path(path)

      # Assert
      assert message =~ "absolute"
    end
  end

  describe "write_dump/2" do
    test "writes the binary to the path", %{tmp_dir: tmp_dir} do
      # Arrange
      path = Path.join(tmp_dir, "dump.bin")
      binary = :binary.copy(<<0xAB>>, 2048)

      # Act
      result = ReadAmiibo.write_dump(path, binary)

      # Assert
      assert result == :ok
      assert File.read!(path) == binary
    end

    test "returns a clear error when the directory does not exist", %{tmp_dir: tmp_dir} do
      # Arrange
      path = Path.join([tmp_dir, "missing", "dump.bin"])

      # Act
      {:error, message} = ReadAmiibo.write_dump(path, <<1, 2, 3>>)

      # Assert
      assert message =~ "Cannot write"
      assert message =~ "no such file or directory"
    end
  end
end

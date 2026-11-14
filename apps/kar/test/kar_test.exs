defmodule KARTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures

  describe "registered?/1" do
    test "is true for a v3 amiibo with the KAR app id" do
      # Arrange
      amiibo = Fixtures.v3_amiibo()

      # Act
      result = KAR.registered?(amiibo)

      # Assert
      assert result
    end

    test "is false for a v3 amiibo with another app id" do
      # Arrange
      amiibo = Fixtures.v3_amiibo(app_id: 0x34F80200)

      # Act
      result = KAR.registered?(amiibo)

      # Assert
      refute result
    end

    test "is false for a v2 amiibo" do
      # Arrange
      amiibo = Amiibo.new(:binary.copy(<<0>>, 540))

      # Act
      result = KAR.registered?(amiibo)

      # Assert
      refute result
    end
  end
end

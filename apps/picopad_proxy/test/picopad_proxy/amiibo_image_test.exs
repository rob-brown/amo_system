defmodule PicopadProxy.AmiiboImageTest do
  use ExUnit.Case, async: true

  alias PicopadProxy.AmiiboImage

  describe "url/1" do
    test "points at the maintained AmiiboAPI fork, which has the Kirby Air Riders icons" do
      # Arrange
      ids = [
        {"1f000000", "04c41e03"},
        {"1f010000", "04c61e03"},
        {"1f020000", "04c71e03"}
      ]

      # Act
      urls = Enum.map(ids, &AmiiboImage.url/1)

      # Assert
      assert urls == [
               "https://raw.githubusercontent.com/8bitDream/AmiiboAPI/dev/images/icon_1f000000-04c41e03.png",
               "https://raw.githubusercontent.com/8bitDream/AmiiboAPI/dev/images/icon_1f010000-04c61e03.png",
               "https://raw.githubusercontent.com/8bitDream/AmiiboAPI/dev/images/icon_1f020000-04c71e03.png"
             ]
    end
  end
end

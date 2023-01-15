defmodule Autopilot.Pointer do
  alias Joycontrol
  alias Vision

  # This confidence level was measured based on moving the 
  # pointer around with 0.3 confidence without ever moving
  # the pointer off the screen. Then taking the minimum 
  # confidence. Sample rate was 100 ms for 10 seconds. 
  @confidence 0.55

  def move(box, pointer, corrections \\ 50)

  def move(_box, _pointer, 0) do
    {:error, :missed}
  end

  def move(box = {x1..x2, y1..y2}, pointer, corrections) when is_binary(pointer) do
    case current_position(pointer) do
      {:ok, {x, y}} when x >= x1 and x <= x2 and y >= y1 and y <= y2 ->
        :ok

      {:ok, position} ->
        {direction, pixels} = vector(position, box)
        duration = move_time(direction, pixels)
        script = "#{direction}:#{duration}\n"

        Joycontrol.raw_script(script)

        # Sleep while the movement is happening.
        Process.sleep(duration)

        # Call recursively in case corrections need to be made.
        # Or need to move in a different axis.
        move(box, corrections - 1)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp current_position(pointer, retries \\ 2)

  defp current_position(_pointer, 0) do
    {:error, :not_found}
  end

  defp current_position(pointer, retries) do
    # Sleep a little bit to let things settle.
    Process.sleep(100)

    case Vision.visible(pointer, confidence: @confidence) do
      {:ok, %{x1: x, y1: y}} ->
        {:ok, {x, y}}

      _ ->
        current_position(pointer, retries - 1)
    end
  end

  defp vector({x, _y}, {_x1..x2, _y1.._y2}) when x > x2 do
    {"left", x - x2}
  end

  defp vector({x, _y}, {x1.._x2, _y1.._y2}) when x < x1 do
    {"right", x1 - x}
  end

  defp vector({_x, y}, {_x1.._x2, _y1..y2}) when y > y2 do
    {"up", y - 2}
  end

  defp vector({_x, y}, {_x1.._x2, y1.._y2}) when y < y1 do
    {"down", y1 - y}
  end

  # This is a very conservative measurement for how far the
  # pointer moves to avoid over shooting. Dependent on
  # capture card screen resolution. There's also some slight
  # acceleration.
  defp move_ms_per_px("up"), do: 2.0
  defp move_ms_per_px("down"), do: 3.0
  defp move_ms_per_px("right"), do: 3.0
  defp move_ms_per_px("left"), do: 4.0

  defp move_time(direction, pixels) when direction in ["left", "right"] do
    trunc(pixels * move_ms_per_px(direction))
    |> clamp(50..800)
  end

  defp move_time(direction, pixels) do
    trunc(pixels * move_ms_per_px(direction))
    |> clamp(50..400)
  end

  defp clamp(value, lo..hi) when lo <= hi do
    value
    |> max(lo)
    |> min(hi)
  end
end

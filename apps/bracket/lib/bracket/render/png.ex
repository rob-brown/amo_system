defmodule Bracket.Render.PNG do
  @moduledoc false

  alias Bracket.Render.SVG

  @spec render(Bracket.Tournament.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def render(%Bracket.Tournament{} = tournament, opts \\ []) do
    if vix_available?() do
      svg = SVG.render(tournament, opts)
      svg_to_png(svg)
    else
      {:error, :vix_not_available}
    end
  end

  @spec available?() :: boolean()
  def available?, do: vix_available?()

  defp vix_available? do
    Code.ensure_loaded?(Vix.Vips.Operation)
  end

  defp svg_to_png(svg) do
    with {:ok, {image, _flags}} <- Vix.Vips.Operation.svgload_buffer(svg),
         {:ok, png_bytes} <- Vix.Vips.Image.write_to_buffer(image, ".png") do
      {:ok, png_bytes}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end

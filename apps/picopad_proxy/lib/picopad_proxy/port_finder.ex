defmodule PicopadProxy.PortFinder do
  @vendor_ids [11_914, 12_259]

  def find(opts \\ []) do
    ports = Keyword.get(opts, :ports, &Circuits.UART.enumerate/0)
    probe = Keyword.get(opts, :probe, &Picopad.probe/2)
    probe_opts = Keyword.get(opts, :probe_opts, [])

    ports.()
    |> candidates()
    |> Enum.reduce_while([], fn port, in_use ->
      case probe.(port, probe_opts) do
        :ok -> {:halt, {:ok, port}}
        {:error, {:open_failed, :eagain}} -> {:cont, [port | in_use]}
        _other -> {:cont, in_use}
      end
    end)
    |> finish()
  end

  defp candidates(ports) when is_map(ports) do
    ports
    |> Enum.filter(fn {_port, info} -> Map.get(info, :vendor_id) in @vendor_ids end)
    |> Enum.map(fn {port, _info} -> port end)
    |> Enum.sort()
  end

  defp candidates(_ports), do: []

  defp finish({:ok, _port} = found), do: found
  defp finish([]), do: {:error, :not_found}
  defp finish(in_use), do: {:error, {:port_in_use, Enum.reverse(in_use)}}
end

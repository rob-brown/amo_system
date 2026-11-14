defmodule SerialLog do
  def main([device, seconds]) do
    System.cmd("stty", ["-f", device, "115200", "raw", "-echo"])
    port = Port.open({:spawn_executable, "/bin/cat"}, [:binary, :exit_status, args: [device]])
    deadline = System.monotonic_time(:millisecond) + String.to_integer(seconds) * 1000
    stream(port, deadline)
    System.halt(0)
  end

  def main(_arguments) do
    IO.puts("usage: elixir serial_log.exs /dev/cu.usbmodemXXXX SECONDS")
  end

  defp stream(port, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining > 0 do
      receive do
        {^port, {:data, data}} ->
          IO.write(data)
          stream(port, deadline)

        {^port, {:exit_status, _status}} ->
          :ok
      after
        remaining -> :ok
      end
    end
  end
end

SerialLog.main(System.argv())

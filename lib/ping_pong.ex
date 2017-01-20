defmodule PingPong do
  def test(n, m) do
    parent = self()
    spawn fn ->
      s = :erlang.monotonic_time(:microsecond)
      {cs1,_} = :erlang.statistics(:context_switches)
      {r1, _} = :erlang.statistics(:reductions)

      first = self()
      last = start(first, n, m)
      send first, :ping
      ping(last, m)
      cost = :erlang.monotonic_time(:microsecond) - s
      IO.puts "#{n} processes, #{m} messages, cost #{cost} us."
      {cs2,_} = :erlang.statistics(:context_switches)
      {r2, _} = :erlang.statistics(:reductions)
      IO.puts "Context switch: #{cs2-cs1}, reductions: #{r2-r1}."

      send parent, :done
    end

    receive do
      :done ->
        :ok
    end
  end

  defp ping(_pid, 0), do: :ok
  defp ping(pid, m) do
    receive do
      :ping ->
        IO.puts "ping"
        send pid, :ping
        ping(pid, m-1)
      _other ->
        ping(pid, m)
    end
  end

  defp start(pid, 0, _m), do: pid
  defp start(pid, n, m) when n>0 do
    p = spawn fn->
      ping(pid, m)
    end
    start(p, n-1, m)
  end

end

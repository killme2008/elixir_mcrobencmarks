defmodule EtsTest do
  use GenServer

  # Client API
  def start_link(:ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def inc(k) do
    :ets.update_counter(:balance_info, k, 1, {k, 0})
    #GenServer.cast(__MODULE__, {:inc, k})
  end

  def get(k) do
    :ets.lookup(:balance_info, k)
    #GenServer.call(__MODULE__, {:get, k})
  end

  def wait(n) do
    receive do
      :ok ->
        i = Process.get :processed
        i = i + 1
        if i < n do
          Process.put :processed, i
          wait(n)
        else
          :ok
        end
    end
  end



  def bench_read_write(n, m) do
    EtsTest.start_link :ok

    start = :erlang.monotonic_time()
    parent = self()
    for i <- (0..n) do
      spawn fn ->
        for j <- (0..m) do
          EtsTest.inc rem(j,10)
          EtsTest.get rem(j,10)
        end
        send parent, :ok
      end
    end

    Process.put :processed, 0
    wait(n)

    elapsed = :erlang.monotonic_time() - start
    |> :erlang.convert_time_unit(:native, :millisecond)

    total =  m*n
    IO.puts "total: #{total}, elapsed: #{elapsed} ms, TPS: #{total/elapsed*1000}."
  end

  def bench_read(n, m) do
    EtsTest.start_link :ok

    #init counter
    for j <- (0..m) do
       EtsTest.inc rem(j,10)
    end

    start = :erlang.monotonic_time()
    parent = self()
    for i <- (0..n) do
      spawn fn ->
        for j <- (0..m) do
          EtsTest.get rem(j,10)
        end
        send parent, :ok
      end
    end

    Process.put :processed, 0
    wait(n)

    elapsed = :erlang.monotonic_time() - start
    |> :erlang.convert_time_unit(:native, :millisecond)

    total =  m*n
    IO.puts "total: #{total}, elapsed: #{elapsed} ms, TPS: #{total/elapsed*1000}."
  end

  def bench_write(n, m) do
    EtsTest.start_link :ok
    start = :erlang.monotonic_time()
    parent = self()
    for i <- (0..n) do
      spawn fn ->
        for j <- (0..m) do
          EtsTest.inc rem(j,10)
        end
        send parent, :ok
      end
    end

    Process.put :processed, 0
    wait(n)

    elapsed = :erlang.monotonic_time() - start
    |> :erlang.convert_time_unit(:native, :millisecond)

    total =  m*n
    IO.puts "total: #{total}, elapsed: #{elapsed} ms, TPS: #{total/elapsed*1000}."
  end

  # Server callbacks
  def init(:ok) do
    #table = :ets.new(:balance_info, [:set, :protected])
    table = :ets.new(:balance_info, [:set, :public,:named_table,
                                     {:read_concurrency, true},
                                     {:write_concurrency, true}])
    {:ok, table}
  end

  def handle_call({:inc, k}, _from, table) do
    ret = :ets.update_counter(table, k, 1, {k, 0})
    {:reply, ret, table}
  end

  def handle_call({:get, k}, _from, table) do
    ret = :ets.lookup(table, k)
    {:reply, ret, table}
  end

  def handle_cast({:inc, k}, table) do
    :ets.update_counter(table, k, 1, {k, 0})
    {:noreply, table}
  end
end

defmodule GlobalId.GlobalUniqueTest do
  use ExUnit.Case

  @tag global: true
  test "globally unique" do

    globals = 0..1023
    |> Enum.map(fn node_id ->
      {:ok, pid} = GenServer.start_link(GlobalId, node_id)
      pid
    end)

    num_iterations = 50_000
    unique_numbers = 1..num_iterations
    |> Enum.map(fn _ ->
      Task.async(fn ->
        [pid] = Enum.take_random(globals, 1)
        GenServer.call(pid, :get_id)
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> Enum.uniq
    |> Enum.count

    assert unique_numbers == num_iterations
  end
end
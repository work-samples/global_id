defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  describe "node_id" do
    test "based on GenServer" do
      {:ok, pid18} = GenServer.start_link(GlobalId, 18)
      {:ok, pid19} = GenServer.start_link(GlobalId, 19)

      assert 18 == GlobalId.node_id(pid18)
      assert 19 == GlobalId.node_id(pid19)
    end
  end

  describe "get_id" do
    test "should be monotonically increasing" do
      {:ok, pid1} = GenServer.start_link(GlobalId, 1)
      first = GlobalId.get_id(pid1)
      second = GlobalId.get_id(pid1)
      third = GlobalId.get_id(pid1)
      assert first != second
      assert second > first
      assert third > first
    end

    test "theoretically support 100 (2^7) calls per millisecond" do
      {:ok, pid1} = GenServer.start_link(GlobalId, 1)

      allIds = Enum.map(0..129, fn _ -> GlobalId.get_id(pid1) end)

      <<_::57,num_0::7>> = <<Enum.at(allIds,0)::64>>
      assert num_0 == 0

      <<_::57,num_1::7>> = <<Enum.at(allIds,1)::64>>
      assert num_1 == 1

      <<_::57,num_127::7>> = <<Enum.at(allIds,127)::64>>
      assert num_127 == 127

      <<_::57,num_128::7>> = <<Enum.at(allIds,128)::64>>
      assert num_128 == 0

      <<_::57,num_128::7>> = <<Enum.at(allIds,129)::64>>
      assert num_128 == 1
    end

  end
end

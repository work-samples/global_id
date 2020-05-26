defmodule GlobalId.PerfTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @tag perf: true
  test "can we get 100k per second" do
    {:ok, pid1} = GenServer.start_link(GlobalId, 1)

    run_benchee = fn ->
      output =
        Benchee.run(
          %{
            "get_id" => fn -> GlobalId.get_id(pid1) end
          },
          formatters: [
            Benchee.Formatters.Console
          ],
          warmup: 0,
          time: 1,
          parallel: 1
        )

      ips = Enum.at(output.scenarios, 0).run_time_data.statistics.ips
      assert ips > 100_000
    end

    capture_io(run_benchee)

    # To view outputs, pipe the above into IO.puts
    # |> IO.puts()
  end
end

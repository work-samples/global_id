defmodule GlobalId do
  use GenServer

  @moduledoc """
  GlobalId module contains an implementation of a guaranteed globally unique id system.
  """

  @doc """
  Return a globally unique 64 bit non-negative integer.

  Each node can be represented with 10 bits (2^10 = 1024)
  we will use that our unique node prefix, and then the
  remaining 54 bits to be unique within the node.

  The underlying call to timestamp is not guaranteed for
  monotonic, and we do not support two calls within the
  same microsecond, but this is a good start.
  """
  @spec get_id(pid()) :: non_neg_integer
  def get_id(pid) do
    <<n::size(64)>> = <<node_id()::10, timestamp()::47, next_id(pid)::7>>
    n
  end

  @doc """
  Return a locally unique non-negative integer.
  Provide the process of the GlobalId GenServer you
  are connecting you.
  """
  @spec next_id(pid()) :: non_neg_integer
  def next_id(pid), do: GenServer.call(pid, :next_id)

  @doc """
  Returns your node id as an integer.
  It will be greater than or equal to 0 and less than 1024.
  It is guaranteed to be globally unique.
  """
  @spec node_id() :: non_neg_integer
  def node_id, do: 18

  @doc """
  Returns timestamp since the epoch in microsecond.
  """
  @spec timestamp() :: non_neg_integer
  def timestamp, do: :os.system_time(:microsecond)

  #
  # GenServer Functionality
  #
  #

  @doc """
  Start our GlobalId GenServer, with our next_id being 0.

  You can start your server with `start_link/2` and then
  send the message `:next_id` the PID as shown below.

      iex> {:ok, pid} = GenServer.start_link(GlobalId, :ok)
      iex> GenServer.call(pid, :next_id)

  These behaviours are also captured in the API above.
  """
  @impl true
  def init(_) do
    {:ok, %{counter: 0}}
  end

  @impl true
  def handle_call(:next_id, _from, %{counter: counter}) do
    {:reply, counter, %{counter: counter + 1}}
  end
end

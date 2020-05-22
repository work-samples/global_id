defmodule GlobalId do
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
  @spec get_id() :: non_neg_integer
  def get_id() do
    <<n::size(64)>> = <<node_id()::10,timestamp()::54>>
    n
  end

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
end

## Problem

Imagine you are building a system to assign unique numbers to each
resource that you manage. You want the ids to be guaranteed unique
i.e. no UUIDs.  Since these ids are globally unique, each id can
only be given out at most once.

The ids are 64 bits long.

There are a fixed number of nodes in the system, up to 1024.

Each node knows its ID at startup and that ID never changes
for the node.

## Solution

### Unsynchronized ID Generation

We are splitting the ID generation between several nodes.
To build a guaranteed-globally-unique generator without
any synchronization between each node, we can split our IDs
between

* X bits to identify the node
* Y bits of unique numbers within a node.

Knowing that we will have at most 1024 (2^10) nodes, we
can reserve the first 10 bits of our number to uniquely
identify the node.

```
XXXXXXXXXX YYYYY.........YYYYY
  10 bits        54 bits
```

### By-Hand Demonstration

Let's demonstrate with an example.  But, we will use
smaller numbers to better visualize the solution.  Let's
make a 5-bit counter split between up to 4 nodes.

In this example, we need 2 bits to identify the nodes, leaving
3 bits for each node to count with.

```
XX YYY
```

So each node's numbers would be split between

```
N0: 00 YYY
N1: 01 YYY
N2: 10 YYY
N3: 11 YYY
```

Now each node just manages uniquely providing a 3-bit number
and it will be guaranteed to be globally unique based on
the uniqueness of those first two bits.


### Elixir Demonstration

This can be represented using
[Bitstrings](https://elixir-lang.org/getting-started/binaries-strings-and-char-lists.html#bitstrings)
in Elixir.

Let's look at our 5-bit example in the iex shell.

Here's the number 9 represented in bits

```
01001
 ^  ^
 8  1
```

In Elixir, this can be (in a slightly verbose manner) done as follows

```elixir
<<0::1,1::1,0::1,0::1,1::1>>
```

For our example nodes, this can be split between 2 bits for
the node and 3 bits for the number

```elxir
<<1::2,1::3>>
```

To extract the `integer` we can use Elixir pattern matching

```elixir
<<n::5>> = <<1::2,1::3>>
```

### Elixir Template Solution

We now have enough to build a template solution for our GlobalId.

```elixir
@doc """
Return a globally unique 64-bit non-negative integer.

Each node can be represented with 10 bits (2^10 = 1024)
we will use our unique node prefix, and then the
remaining 54 bits to be unique within the node.

The underlying call to timestamp is not guaranteed for
monotonic, and we do not support two calls within the
same microsoft, but this is a good start.
"""
@spec get_id() :: non_neg_integer
def get_id() do
  <<n::size(64)>> = <<node_id()::10,next_id()::54>>
  n
end
```

The `node_id()` is assigned automatically from the node itself.
The specification for the `next_id()` now only needs to be
unique within the node itself.

```elixir
@doc """
Return a locally unique non-negative integer.
"""
@spec next_id() :: non_neg_integer
def next_id
```

Before we implement the `next_id()`, let's analyze how
many numbers can be generated so we can evaluate
the appropriateness of our solution.


### How Many Unique Numbers are Possible

Our system can, at most, distribute up to a million-trillion
unique IDs (2^64 = 64-bit number).

```
18,446,744,073,709,552,000 (2^64)
mT  kT   T   B   M   k
```

We are splitting our generator between (up to) 1024 nodes
so each node can, at most, distribute up to a thousand-trillion
unique IDs (2^54)

```
18,014,398,509,481,984
kT   T   B   M
```

### Timestamp solution

The timestamp solution is simple but offers two possible
problems.

First, when will the numbers run out.  And second,
will there ever be two requests at the exact same time
causing our solution to (incorrectly) return duplicate IDs.

#### How long will 2^54 last?

Today's date (approx) is 1.5 billion milliseconds

```
1,590,159,116
B   M
```

Even if we supported units in microseconds, that
is still only about 1.5 trillion, leaving each node
with only 18,013 trillion possible  values instead of
18,014 trillion.

There are about 30 billion milliseconds each year
(365\*24\*60\*60\*1000), so we have until the year 600k
until we exhaust 2^54 numbers based on a timestamp.

#### Two Requests At the Same Time?

This is a bigger concern for uniqueness.

If our timestamp can only resolve to milliseconds,
and we expect about 100k requests per second, that is
around 100 requests every millisecond, which is not precise enough.

If we had microtime resolution, **and** if we could guarantee
that our `get_id()` would perform not faster than a `1μ ms`
then our solution below would be sufficient for our needs.

```elixir
@doc """
Return a locally unique non-negative integer.
"""
@spec next_id() :: non_neg_integer
def next_id, do: :os.system_time(:microsecond)
```

If we cannot guarantee those conditions then we need to
look at `GlobalId` maintaining its own count.

### How much to count?

Our system could receive 100,000 requests a second.
But we don't know the distribution within the second.
Maybe they all arrive at once, or maybe they are
evenly distributed about 100 every millisecond.

##### Counting 100k every second

If we have no guarantees about how the requests are
distributed within a second, then we need 17 bits to
track those 100k per second requests (2^17=131k)

Let us revisit our 64-bit number, where we have

* 10 X bits for the node,
* 37 Y bits for the timestamp, and
* 17 Z bits for the counter.

```
XXXXXXXXXX YYYYY.........YYYYY  ZZZZZ.........ZZZZ
  10 bits        37 bits              17 bits
```

We now have fewer bits for our timestamp, so let us
see if we can still reasonably generate numbers for a long time.

At millisecond precision, 37 bits only supports 137 billion
numbers or 5 years.

```
137,438,953,472
  B   M
```

Clearly not enough.

#### To-The-Second Precision

We could consider to-the-second precision for our timestamp
as we would be managing sub-second counting, this would give
us around 4.5k years of unique numbers.

#### Counting 100 every millisecond

We could also see if our messages would be evenly distributed
throughout every millisecond, which would require only 7 bits
to track our counter as at most 100 requests would arrive
every millisecond (2^7=128).

Our new scheme for the 64-bit number, would be

* 10 X bits for the node,
* 47 Y bits for the timestamp, and
* 7 Z bits for the counter.

```
XXXXXXXXXX YYYYY.........YYYYY  ZZZZZ.........ZZZZ
  10 bits        47 bits              7 bits
```

At 47 bits, our timestamp supports up to 140 trillion numbers,
at at 30 billion milliseconds per year, our system would last
about 4.5k years of generating unique numbers.

```
140,737,488,355,328
  T   B   M
```

If we wanted to count to 1000 (instead of a 100), then we could
support up to 1000 bursts every millisecond (instead of the
uniformly 10/ms) then our system would last for about 500 years.

```
17,592,186,044,416
 T    B   M
```

#### Why keep the timestamp?

You could argue if your system can count to a thousand, or
to one-hundred thousand, why not have it do all the counting?

Down-time and failures.

If a node goes offline, then when we bring it back up, or
if a new node is brought back up in its stead, we do not
need to manage any external state and the counter will continue
to generate globally unique numbers.  This works nicely with
Elixir/Erlang as our `GlobalId` could be part of a supervision tree
that could automatically re-start it on failure.

### Counting in Elixir

Elixir (and Erlang) offer several mechanisms to
support internal state.  The most commonly used is a GenServer
(which stands for a Generic Server) which we will use below.

We will configure our GenServer with

```elixir
defmodule GlobalId do
  use GenServer

  @impl true
  def init(_) do
    {:ok, %{counter: 0}}
  end

end
```

And our counter will increment the state on each request.

```elixir
  @impl true
  def handle_call(:next_id, _from, %{counter: counter}) do
    {:reply, counter, %{counter: counter + 1}}
  end
```

We will update our `get_id()` and `next_id()` implementations
to use this counter.

```elixir
  @spec get_id(pid()) :: non_neg_integer
  def get_id(pid) do
    <<n::size(64)>> = <<node_id()::10, timestamp()::47, next_id(pid)::7>>
    n
  end

  @spec next_id(pid()) :: non_neg_integer
  def next_id(pid), do: GenServer.call(pid, :next_id)
```

#### Full Solution

Our full solution using the GenServer is shown below.


```elixir
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
```

### Debugging our Implementation

From the elixir shell (within a project holding our `GlobalId`)

```elixir
iex -S mix
```

We can start a new GlobalId server.

```elixir
iex> {:ok, pid} = GenServer.start_link(GlobalId, :ok)
```

And then use the `pid` to request the next IDs.

```elixir
iex> GlobalId.get_id(pid)
```

We can also test our `next_id()` function.

```elixir
iex> GlobalId.next_id(pid)
```


### Implementing the Node ID

Right now our NodeId is hard-coded, let's expand that
to grab from our internal state.

```elixir
defmodule GlobalId do
  use GenServer

  @moduledoc """
  GlobalId module contains an implementation of a guaranteed globally unique id system.
  """

  @doc """
  Return a globally unique 64-bit non-negative integer.

  Each node can be represented with 10 bits (2^10 = 1024)
  we will use our unique node prefix, and then the
  remaining 54 bits to be unique within the node.

  The underlying call to timestamp is not guaranteed for
  monotonic, and we do not support two calls within the
  same microsecond, but this is a good start.
  """
  @spec get_id(pid()) :: non_neg_integer
  def get_id(pid), do: GenServer.call(pid, :get_id)

  @doc """
  Returns your node id as an integer.
  It will be greater than or equal to 0 and less than 1024.
  It is guaranteed to be globally unique.
  """
  @spec node_id(pid()) :: non_neg_integer
  def node_id(pid), do: GenServer.call(pid, :node_id)

  @doc """
  Returns timestamp since the epoch in microseconds.
  """
  @spec timestamp() :: non_neg_integer
  def timestamp, do: :os.system_time(:microsecond)

  #
  # GenServer Functionality
  #
  #

  @doc """
  Start our GlobalId GenServer, with our next_id being 0.

  You can start your server with

      iex> {:ok, pid} = GenServer.start_link(GlobalId, 18)

  And then send messages to your server using

      iex> GenServer.call(pid, :get_id)

  These behaviours are also captured in the API above.
  """
  @impl true
  def init(node_id) do
    {:ok, %{node_id: node_id, counter: 0}}
  end

  @impl true
  def handle_call(:node_id, _from, %{node_id: node_id} = state) do
    {:reply, node_id, state}
  end

  @impl true
  def handle_call(:get_id, _from, %{node_id: node_id, counter: counter} = state) do
    <<id::size(64)>> = <<node_id::10, timestamp()::47, counter::7>>
    {:reply, id, %{state | counter: counter + 1}}
  end
end
```

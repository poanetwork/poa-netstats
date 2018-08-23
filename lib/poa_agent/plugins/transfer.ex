defmodule POAAgent.Plugins.Transfer do

  @moduledoc """
  Defines a Transfer Plugin.

  A Transfer plugin receives data from Collectors. It uses the Collector's `label` in order to
  differenciate from multiple Collectors.

  `POAAgent` app reads the Transfers configuration from the `config.exs` file when bootstrap and will create a
  process per each one of them. That configuration is referenced by :transfers key.

      config :poa_agent,
         :transfers,
         [
           {name, module, args}
         ]

  for example

      config :poa_agent,
         :transfers,
         [
           {:my_transfer, POAAgent.Plugins.Transfers.MyTransfer, [ws_key: "mykey", other_stuff: "hello"]}
         ]

  `name`, `module` and `args` must be defined in the configuration file.

  - `name`: Name for the new created process. Must be unique
  - `module`: Module which implements the Transfer behaviour
  - `args`: Initial args which will be passed to the `init_transfer/1` function

  ## Implementing A Transfer Plugin

  In order to implement your Transfer Plugin you must implement 3 functions.

  - `init_transfer/1`: Called only once when the process starts
  - `data_received/4`: This function is called every time a Collector sends metrics to the Transfer
  - `handle_message/1`: This is called when the transfer process receives an Erlang message
  - `terminate/1`: Called just before stopping the process

  This is a simple example of custom Transfer Plugin

      defmodule POAAgent.Plugins.Transfers.MyTransfer do
        use POAAgent.Plugins.Transfer

        def init_transfer(args) do
          {:ok, :no_state}
        end

        def data_received(label, metric_type, data, state) do
          IO.puts "Received data from the collector referenced by label"
          {:ok, :no_state}
        end

        def handle_message(_message, state) do
          {:ok, state}
        end

        def terminate(_state) do
          :ok
        end

      end

  """

  @doc """
    A callback executed when the Transfer Plugin starts.
    The argument is retrieved from the configuration file when the Transfer is defined
    It must return `{:ok, state}`, that `state` will be keept as in `GenServer` and can be
    retrieved in the `data_received/2` function.
  """
  @callback init_transfer(args :: term()) ::
      {:ok, any()}

  @doc """
    In this callback is called when a Collector sends data to this Transfer.

    Regarding the parameters, `label` identifies the Collector, `metric_type` is the metric type in String format, it is used in order
    to know which kind of data we are sending, the `data` is the real data received, and the `state` is the Collector's state

    It must return `{:ok, state}`.
  """
  @callback data_received(label :: atom(), metric_type :: String.t, data :: any(), state :: any()) :: {:ok, any()}

  @doc """
    In this callback is called when the Transfer process receives an erlang message.

    It must return `{:ok, state}`.
  """
  @callback handle_message(msg :: any(), state :: any()) :: {:ok, state :: any()}

  @doc """
    This callback is called just before the Process goes down. This is a good place for closing connections.
  """
  @callback terminate(state :: term()) :: term()

  @doc false
  defmacro __using__(_opt) do
    quote do
      @behaviour POAAgent.Plugins.Transfer

      @doc false
      def start_link(%{name: name} = state) do
        GenServer.start_link(__MODULE__, state, name: name)
      end

      @doc false
      def init(state) do
        {:ok, internal_state} = init_transfer(state[:args])
        {:ok, Map.put(state, :internal_state, internal_state)}
      end

      @doc false
      def handle_call(_msg, _from, state) do
        {:noreply, state}
      end

      @doc false
      def handle_info(msg, state) do
        {:ok, internal_state} = handle_message(msg, state.internal_state)
        {:noreply, %{state | internal_state: internal_state}}
      end

      @doc false
      def handle_cast(%{label: label, metric_type: metric_type, data: data}, state) do
        {:ok, internal_state} = data_received(label, metric_type, data, state.internal_state)
        {:noreply, %{state | internal_state: internal_state}}
      end
      def handle_cast(msg, state) do
        {:noreply, state}
      end

      @doc false
      def code_change(_old, state, _extra) do
        {:ok, state}
      end

      @doc false
      def terminate(_reason, state) do
        terminate(state)
      end

    end
  end

end

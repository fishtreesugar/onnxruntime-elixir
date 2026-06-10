defmodule OnnxRuntime.Serving do
  @moduledoc """
  `Nx.Serving` adapter for `OnnxRuntime.Model`.
  """

  @behaviour Nx.Serving

  @impl true
  def init(_inline_or_process, model, [_defn_options]) do
    {:ok, fn input -> OnnxRuntime.run(model, input) end}
  end

  @impl true
  def handle_batch(batch, _partition, fun) do
    output = fun.(Nx.Defn.jit_apply(&Function.identity/1, [batch]))
    {:execute, fn -> {output, :server_info} end, fun}
  end
end

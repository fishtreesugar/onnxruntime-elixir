defmodule OnnxRuntime do
  @moduledoc """
  Elixir bindings for Microsoft ONNX Runtime.

  This module intentionally mirrors the small `Ortex` facade: load a model with
  `load/3`, then run inference with `run/2`.
  """

  @doc """
  Loads an ONNX model from disk.

  `execution_providers` currently supports `[:cpu]`. `optimization_level`
  maps to ONNX Runtime graph optimization levels:

    * `0` - disabled
    * `1` - basic
    * `2` - extended
    * `3` - all
  """
  def load(path), do: load(path, [:cpu], 3)
  def load(path, execution_providers), do: load(path, execution_providers, 3)

  def load(path, execution_providers, optimization_level) do
    OnnxRuntime.Model.load(path, execution_providers, optimization_level)
  end

  @doc """
  Runs a forward pass through a model.

  A single input tensor may be passed directly. Multiple inputs should be passed
  as a tuple in model input order. Outputs are returned as a tuple of `Nx.Tensor`
  values backed by `OnnxRuntime.Backend`.
  """
  defdelegate run(model, tensors), to: OnnxRuntime.Model
end

defmodule OnnxRuntime.Model do
  @moduledoc """
  A loaded ONNX Runtime inference session.
  """

  @enforce_keys [:reference]
  defstruct [:reference]

  @doc false
  def load(path, execution_providers \\ [:cpu], optimization_level \\ 3) do
    path
    |> OnnxRuntime.Native.init(execution_providers, optimization_level)
    |> then(&%__MODULE__{reference: &1})
  end

  @doc false
  def run(%__MODULE__{} = model, tensor) when not is_tuple(tensor) do
    run(model, {tensor})
  end

  def run(%__MODULE__{reference: model}, tensors) when is_tuple(tensors) do
    inputs =
      tensors
      |> Tuple.to_list()
      |> Enum.map(&Nx.backend_transfer(&1, OnnxRuntime.Backend))
      |> Enum.map(fn %Nx.Tensor{data: %OnnxRuntime.Backend{ref: ref}} -> ref end)

    model
    |> OnnxRuntime.Native.run(inputs)
    |> Enum.map(fn {ref, shape, kind, bits} ->
      shape = List.to_tuple(shape)

      %Nx.Tensor{
        data: %OnnxRuntime.Backend{ref: ref},
        shape: shape,
        type: {kind, bits},
        names: List.duplicate(nil, tuple_size(shape))
      }
    end)
    |> List.to_tuple()
  end
end

defimpl Inspect, for: OnnxRuntime.Model do
  import Inspect.Algebra

  def inspect(%OnnxRuntime.Model{reference: model}, inspect_opts) do
    {inputs, outputs} = OnnxRuntime.Native.show_session(model)

    force_unfit(
      concat([
        color("#OnnxRuntime.Model<", :map, inspect_opts),
        line(),
        nest(concat(["  inputs: ", Inspect.Algebra.to_doc(inputs, inspect_opts)]), 2),
        line(),
        nest(concat(["  outputs: ", Inspect.Algebra.to_doc(outputs, inspect_opts)]), 2),
        color(">", :map, inspect_opts)
      ])
    )
  end
end

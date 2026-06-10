defmodule OnnxRuntime.Backend do
  @moduledoc """
  Storage-only `Nx.Backend` for tensors owned by ONNX Runtime.

  It is meant for input/output transfer and inspection, not as a general Nx
  numerical backend.
  """

  @behaviour Nx.Backend
  @enforce_keys [:ref]
  @derive {Nx.Container, containers: [:ref]}

  defstruct [:ref]

  alias Nx.Tensor, as: T
  alias OnnxRuntime.Backend, as: B

  @impl true
  def init(opts) do
    if opts != [] do
      raise ArgumentError, "OnnxRuntime.Backend accepts no options"
    end

    opts
  end

  @impl true
  def from_binary(%T{shape: shape, type: type} = tensor, binary, _backend_options) do
    ref = OnnxRuntime.Native.from_binary(binary, Tuple.to_list(shape), type)
    put_in(tensor.data, %B{ref: ref})
  end

  @impl true
  def to_binary(%T{data: %B{ref: ref}}, limit) do
    OnnxRuntime.Native.to_binary(ref, normalize_limit(limit))
  end

  @impl true
  def backend_transfer(tensor, OnnxRuntime.Backend, _opts), do: tensor
  def backend_transfer(tensor, Nx.Tensor, _opts), do: tensor

  def backend_transfer(tensor, backend, opts) do
    backend.from_binary(tensor, to_binary(tensor, :infinity), opts)
  end

  @impl true
  def backend_copy(tensor, backend, opts), do: backend_transfer(tensor, backend, opts)

  @impl true
  def backend_deallocate(_tensor), do: :ok

  @impl true
  def inspect(%T{} = tensor, inspect_opts) do
    limit = if inspect_opts.limit == :infinity, do: :infinity, else: inspect_opts.limit + 1

    tensor
    |> to_binary(min_limit(limit, Nx.size(tensor)))
    |> then(&Nx.Backend.inspect(tensor, &1, inspect_opts))
    |> Inspect.Algebra.concat(Inspect.Algebra.line())
    |> Inspect.Algebra.concat("OnnxRuntime.Backend")
  end

  @impl true
  def to_batched(_out, _tensor, _opts), do: unsupported!(:to_batched)

  @impl true
  def from_pointer(_opaque_pointer, _type, _shape, _backend_opts, _opts),
    do: unsupported!(:from_pointer)

  @impl true
  def to_pointer(_tensor, _opts), do: unsupported!(:to_pointer)

  @impl true
  def reshape(out, %T{} = tensor) do
    ref =
      OnnxRuntime.Native.from_binary(
        to_binary(tensor, :infinity),
        Tuple.to_list(out.shape),
        out.type
      )

    put_in(out.data, %B{ref: ref})
  end

  @impl true
  def squeeze(out, %T{} = tensor, _axes) do
    reshape(out, tensor)
  end

  @impl true
  def slice(out, %T{} = tensor, start_indices, lengths, strides) do
    result =
      tensor
      |> backend_transfer(Nx.BinaryBackend, [])
      |> Nx.slice(start_indices, lengths, strides: strides)
      |> backend_transfer(OnnxRuntime.Backend, [])

    %T{data: data} = result
    %{out | data: data}
  end

  @impl true
  def concatenate(out, tensors, axis) do
    types = Enum.map(tensors, & &1.type) |> Enum.uniq()

    if length(types) != 1 do
      raise "OnnxRuntime does not currently support concatenation of vectors with differing types."
    end

    result =
      tensors
      |> Enum.map(&backend_transfer(&1, Nx.BinaryBackend, []))
      |> Nx.concatenate(axis: axis)
      |> backend_transfer(OnnxRuntime.Backend, [])

    %T{data: data} = result
    %{out | data: data}
  end

  defp normalize_limit(:infinity), do: 0
  defp normalize_limit(limit) when is_integer(limit) and limit >= 0, do: limit

  defp min_limit(:infinity, _size), do: :infinity
  defp min_limit(limit, size), do: min(limit, size)

  defp unsupported!(op) do
    raise "operation #{op} is not supported on OnnxRuntime.Backend"
  end

  funs = Nx.Backend.behaviour_info(:callbacks) -- Module.definitions_in(__MODULE__, :def)

  @doc false
  def __unimplemented__, do: unquote(funs)

  for {fun, arity} <- funs do
    args = Macro.generate_arguments(arity, __MODULE__)

    @impl true
    def unquote(fun)(unquote_splicing(args)) do
      unsupported!(unquote(fun))
    end
  end
end

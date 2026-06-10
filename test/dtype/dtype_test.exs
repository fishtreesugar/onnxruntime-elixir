defmodule OnnxRuntime.TestDtypes do
  use ExUnit.Case

  {tensor, _} = Nx.Random.uniform(Nx.Random.key(42), 0, 256, shape: {100, 100})
  @tensor tensor

  defp bin_binary(dtype) do
    %{data: %{state: bin}} = @tensor |> Nx.as_type(dtype)
    bin
  end

  defp bin_onnxruntime(dtype) do
    %{data: %{state: bin}} =
      @tensor
      |> Nx.as_type(dtype)
      |> Nx.backend_transfer(OnnxRuntime.Backend)
      |> Nx.backend_transfer(Nx.BinaryBackend)

    bin
  end

  test "size 0 tensor" do
    %{data: %{state: bin1}} = Nx.tensor(0)

    %{data: %{state: bin2}} =
      Nx.tensor(0)
      |> Nx.backend_transfer(OnnxRuntime.Backend)
      |> Nx.backend_transfer(Nx.BinaryBackend)

    assert bin1 == bin2
  end

  for dtype <- [:u8, :u16, :u32, :u64, :s8, :s16, :s32, :s64, :f16, :bf16, :f32, :f64] do
    test "#{dtype} conversion" do
      assert bin_binary(unquote(dtype)) == bin_onnxruntime(unquote(dtype))
    end
  end
end

defmodule OnnxRuntimeTest do
  use ExUnit.Case, async: true

  test "public facade exports ortex-style API" do
    Code.ensure_loaded!(OnnxRuntime)

    assert function_exported?(OnnxRuntime, :load, 1)
    assert function_exported?(OnnxRuntime, :load, 2)
    assert function_exported?(OnnxRuntime, :load, 3)
    assert function_exported?(OnnxRuntime, :run, 2)
  end

  test "loads and runs a simple ONNX model" do
    model_path = Path.join(System.tmp_dir!(), "onnxruntime_elixir_add.onnx")
    File.write!(model_path, add_model())

    model = OnnxRuntime.load(model_path)

    assert inspect(model) =~ ~s(inputs: [{"x", "Float32", [2]}])
    assert inspect(model) =~ ~s(outputs: [{"y", "Float32", [2]}])

    input = Nx.tensor([1.0, 2.5], type: :f32)

    assert {%Nx.Tensor{} = output} = OnnxRuntime.run(model, input)
    assert Nx.to_flat_list(Nx.backend_transfer(output, Nx.BinaryBackend)) == [2.0, 5.0]
  end

  @tag :resnet50
  test "resnet50" do
    model = OnnxRuntime.load("./models/resnet50.onnx")

    input = Nx.broadcast(0.0, {1, 3, 224, 224})
    {output} = OnnxRuntime.run(model, {input})
    argmax = output |> Nx.backend_transfer() |> Nx.argmax(axis: 1)

    assert argmax == Nx.tensor([499])
  end

  @tag :resnet50
  test "Nx.Serving with resnet50" do
    model = OnnxRuntime.load("./models/resnet50.onnx")

    serving = Nx.Serving.new(OnnxRuntime.Serving, model)
    batch = Nx.Batch.stack([{Nx.broadcast(0.0, {3, 224, 224})}])
    {result} = Nx.Serving.run(serving, batch)
    assert result |> Nx.backend_transfer() |> Nx.argmax(axis: 1) == Nx.tensor([499])
  end

  test "Nx.Serving with tinymodel" do
    model = OnnxRuntime.load("./models/tinymodel.onnx")

    serving = Nx.Serving.new(OnnxRuntime.Serving, model)

    batch =
      Nx.Batch.stack([
        {Nx.broadcast(0, {100}) |> Nx.as_type(:s32),
         Nx.broadcast(0.0, {100}) |> Nx.as_type(:f32)},
        {Nx.broadcast(1, {100}) |> Nx.as_type(:s32),
         Nx.broadcast(1.0, {100}) |> Nx.as_type(:f32)},
        {Nx.broadcast(2, {100}) |> Nx.as_type(:s32), Nx.broadcast(2.0, {100}) |> Nx.as_type(:f32)}
      ])

    {%Nx.Tensor{shape: {3, 10}}, %Nx.Tensor{shape: {3, 10}}, %Nx.Tensor{shape: {3, 10}}} =
      Nx.Serving.run(serving, batch)
  end

  defp add_model do
    model([
      field_varint(1, 7),
      field_string(2, "onnxruntime-elixir"),
      field_msg(7, graph()),
      field_msg(8, opset_import(13))
    ])
  end

  defp graph do
    message([
      field_msg(1, add_node()),
      field_string(2, "add_graph"),
      field_msg(11, value_info("x")),
      field_msg(12, value_info("y"))
    ])
  end

  defp add_node do
    message([
      field_string(1, "x"),
      field_string(1, "x"),
      field_string(2, "y"),
      field_string(4, "Add")
    ])
  end

  defp value_info(name) do
    message([
      field_string(1, name),
      field_msg(2, tensor_type())
    ])
  end

  defp tensor_type do
    message([
      field_msg(
        1,
        message([
          field_varint(1, 1),
          field_msg(2, shape([2]))
        ])
      )
    ])
  end

  defp shape(dims) do
    dims
    |> Enum.map(fn dim -> field_msg(1, message([field_varint(1, dim)])) end)
    |> message()
  end

  defp opset_import(version) do
    message([field_varint(2, version)])
  end

  defp model(fields), do: message(fields)
  defp message(fields), do: IO.iodata_to_binary(fields)

  defp field_varint(field, value), do: [varint(Bitwise.bsl(field, 3)), varint(value)]
  defp field_string(field, value), do: field_bytes(field, value)
  defp field_msg(field, value), do: field_bytes(field, value)

  defp field_bytes(field, value) do
    [varint(Bitwise.bsl(field, 3) + 2), varint(byte_size(value)), value]
  end

  defp varint(value) when value < 128, do: <<value>>

  defp varint(value) do
    <<Bitwise.band(value, 0x7F) + 0x80>> <> varint(Bitwise.bsr(value, 7))
  end
end

exclude =
  if File.exists?("models/resnet50.onnx") do
    []
  else
    IO.warn(
      """
      skipping resnet50 tests because model is not available.
      Provide models/resnet50.onnx for the complete Ortex-compatible test suite
      """,
      []
    )

    [:resnet50]
  end

ExUnit.start(exclude: exclude)

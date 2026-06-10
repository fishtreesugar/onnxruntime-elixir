defmodule OnnxRuntime.Native do
  @moduledoc false

  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:onnxruntime), ~c"onnxruntime")
    :erlang.load_nif(path, 0)
  end

  def init(_model_path, _execution_providers, _optimization_level),
    do: :erlang.nif_error(:nif_not_loaded)

  def run(_model, _inputs), do: :erlang.nif_error(:nif_not_loaded)
  def show_session(_model), do: :erlang.nif_error(:nif_not_loaded)
  def from_binary(_binary, _shape, _type), do: :erlang.nif_error(:nif_not_loaded)
  def to_binary(_tensor, _limit), do: :erlang.nif_error(:nif_not_loaded)
end

# OnnxRuntime

Elixir bindings for [Microsoft ONNX Runtime](https://github.com/microsoft/onnxruntime),
built with [Fine](https://github.com/elixir-nx/fine), `elixir_make`, and `Nx`.

The public API follows the shape of `elixir-nx/ortex`:

```elixir
model = OnnxRuntime.load("./model.onnx")
{output} = OnnxRuntime.run(model, Nx.broadcast(0.0, {1, 3, 224, 224}))
```

Inspecting a model shows its ONNX inputs and outputs:

```elixir
#OnnxRuntime.Model<
  inputs: [{"input", "Float32", [nil, 3, 224, 224]}]
  outputs: [{"output", "Float32", [nil, 1000]}]
>
```

## Installation

```elixir
def deps do
  [
    {:onnxruntime, "~> 0.1.0"}
  ]
end
```

Until precompiled artifacts are published, local compilation requires a C++17
compiler and either:

  * network access during `mix compile`, so `scripts/fetch_onnxruntime.sh` can
    download the ONNX Runtime CPU archive; or
  * `ORT_INCLUDE_DIR` and `ORT_LIB_DIR` pointing at an existing ONNX Runtime
    distribution.

The default ONNX Runtime version is `1.26.0`. Override it with:

```shell
ONNXRUNTIME_VERSION=1.26.0 mix compile
```

## Precompilation

This project is configured for `elixir_make` precompiled NIF artifacts through
`CCPrecompiler`.

For a release build:

```shell
MIX_ENV=prod mix elixir_make.precompile
MIX_ENV=prod mix elixir_make.checksum --all --ignore-unavailable
```

The precompiled archive includes the NIF and `libonnxruntime` runtime library
from `priv/`.

The default precompile targets follow the official ONNX Runtime CPU archives for
version `1.26.0`: macOS arm64, Linux x64, and Linux aarch64. macOS x86_64 is
not enabled by default because ONNX Runtime v1.26.0 does not publish an
`onnxruntime-osx-x86_64` archive.


Set `ONNXRUNTIME_ELIXIR_GITHUB_URL` or `ONNXRUNTIME_PRECOMPILE_URL` before
publishing if your release artifacts live somewhere other than the default
GitHub repository URL.

## Scope

The first implementation supports CPU execution and common tensor dtypes:
`f32`, `f64`, signed/unsigned integer tensors, and `bool`. Additional execution
providers can be added in the NIF by appending provider-specific session options.

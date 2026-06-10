defmodule OnnxRuntime.MixProject do
  use Mix.Project

  @version "0.1.0-rc.0"
  @onnxruntime_version "1.26.0"
  @github_repo System.get_env("GITHUB_REPOSITORY") || "fishtreesugar/onnxruntime-elixir"
  @github_url System.get_env("ONNXRUNTIME_ELIXIR_GITHUB_URL") ||
                "https://github.com/#{@github_repo}"
  @precompile_url System.get_env("ONNXRUNTIME_PRECOMPILE_URL") ||
                    "#{@github_url}/releases/download/v#{@version}/@{artefact_filename}"

  def project do
    [
      app: :onnxruntime,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_clean: ["clean"],
      make_env: &make_env/0,
      make_precompiler: {:nif, CCPrecompiler},
      make_precompiler_url: @precompile_url,
      make_precompiler_filename: "onnxruntime",
      make_precompiler_priv_paths: ["onnxruntime.*", "libonnxruntime*"],
      make_precompiler_nif_versions: [
        versions: ["2.16", "2.17", "2.18"]
      ],
      name: "OnnxRuntime",
      description: "Elixir bindings for Microsoft ONNX Runtime",
      source_url: @github_url,
      homepage_url: @github_url,
      docs: docs(),
      package: package(),
      deps: deps(),
      cc_precompiler: cc_precompiler()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp make_env do
    %{
      "FINE_INCLUDE_DIR" => Fine.include_dir(),
      "ONNXRUNTIME_VERSION" => @onnxruntime_version
    }
  end

  defp cc_precompiler do
    [
      only_listed_targets: true,
      compilers: %{
        {:unix, :darwin} => %{
          "aarch64-apple-darwin" => {
            "gcc",
            "g++",
            "<%= cc %> -arch arm64",
            "<%= cxx %> -arch arm64"
          }
        },
        {:unix, :linux} => %{
          "x86_64-linux-gnu" => "x86_64-linux-gnu-",
          "aarch64-linux-gnu" => "aarch64-linux-gnu-"
        }
      }
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.12"},
      {:fine, "~> 0.1.6", runtime: false},
      {:elixir_make, "~> 0.10", runtime: false},
      {:cc_precompiler, "~> 0.1.6", runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url,
        "ONNX Runtime" => "https://github.com/microsoft/onnxruntime"
      },
      files: ~w(.formatter.exs README.md LICENSE Makefile mix.exs lib c_src scripts checksum.exs)
    ]
  end
end

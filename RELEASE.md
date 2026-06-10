# Release Process

This document describes how to publish a new `onnxruntime` release with precompiled NIF artifacts.

`onnxruntime` uses `elixir_make` with `CCPrecompiler`. The precompiled tarballs include the native NIF and the ONNX Runtime shared library sidecar files declared by `make_precompiler_priv_paths` in `mix.exs`.

## Supported Precompile Targets

| Target | Runner | Notes |
|---|---|---|
| `aarch64-apple-darwin` | `macos-14` | Apple Silicon, native build |
| `x86_64-linux-gnu` | `ubuntu-latest` | Native Linux x86_64 build |
| `aarch64-linux-gnu` | `ubuntu-latest` | Cross-compiled with `gcc-aarch64-linux-gnu` and `g++-aarch64-linux-gnu` |

The workflow runs on OTP `27` and `28` with Elixir `1.19`. The generated artifact name includes the NIF version, target, and package version, for example:

```text
onnxruntime-nif-2.17-aarch64-linux-gnu-0.1.0-rc.1.tar.gz
```

`mix.exs` currently allows NIF versions `2.16`, `2.17`, and `2.18`, but only artifacts produced by the release workflow and listed in `checksum.exs` are available as precompiled downloads.

Targets outside the matrix, or NIF versions without a matching artifact, fall back to source build through `elixir_make`/`CCPrecompiler`. Consumers on those paths need a C++17 toolchain and network access to download the ONNX Runtime CPU archive, unless `ONNXRUNTIME_DIR` points to an existing ONNX Runtime installation.

## Cutting A Release

### 1. Bump Version

Edit `mix.exs` and update `@version`.

```elixir
@version "0.1.0-rc.1"
```

Confirm the ONNX Runtime version is intentional.

```elixir
@onnxruntime_version "1.26.0"
```

If a changelog exists, update it in the same release branch.

### 2. Run Local Checks

```sh
mix deps.get
mix format --check-formatted
mix test
mix hex.build --unpack
```

Inspect the file list printed by `mix hex.build --unpack`. The package should include source files and `checksum.exs`; it should not include large local test/model files such as `models/resnet50.onnx`.

Remove the local unpack directory after inspection.

```sh
rm -rf onnxruntime-<version>
```

### 3. Commit And Push The Release Prep

```sh
git add mix.exs checksum.exs README.md RELEASE.md .github/workflows
git commit -m "Prepare v0.1.0-rc.1 release"
git push origin main
```

Adjust the file list and commit message to the actual change set.

### 4. Push A Release Tag

Precompiled artifacts are created by `.github/workflows/precompile.yml` when a version tag is pushed.

```sh
git tag v0.1.0-rc.1
git push origin v0.1.0-rc.1
```

For release candidates, tags containing `-rc` are marked as GitHub prereleases by the workflow.

Watch the workflow run:

```sh
gh run list --repo fishtreesugar/onnxruntime-elixir --limit 10
gh run watch <run-id> --repo fishtreesugar/onnxruntime-elixir --exit-status
```

Verify the release and assets:

```sh
gh release view v0.1.0-rc.1 --repo fishtreesugar/onnxruntime-elixir --json tagName,isPrerelease,url,assets
```

If a matrix cell fails, fix the issue and publish a new release-candidate tag such as `v0.1.0-rc.1`. Avoid force-moving a public tag unless it has clearly failed and no consumers can reasonably depend on it yet.

### 5. Generate Or Update Checksums

After the GitHub Release assets exist, regenerate `checksum.exs` from the published tarballs.

```sh
MIX_ENV=prod mix elixir_make.checksum --all --ignore-unavailable
```

Use `--print` if you want to inspect the generated map before replacing the file.

```sh
MIX_ENV=prod mix elixir_make.checksum --all --ignore-unavailable --print
```

Inspect the diff. Every artifact intended for this release should appear with the exact artifact name and SHA-256 digest from GitHub.

Example:

```elixir
%{
  "onnxruntime-nif-2.17-aarch64-apple-darwin-0.1.0-rc.1.tar.gz" => "sha256:...",
  "onnxruntime-nif-2.17-aarch64-linux-gnu-0.1.0-rc.1.tar.gz" => "sha256:...",
  "onnxruntime-nif-2.17-x86_64-linux-gnu-0.1.0-rc.1.tar.gz" => "sha256:..."
}
```

Commit and push the checksum update to `main`.

```sh
git add checksum.exs
git commit -m "Align release checksums"
git push origin main
```

Do not move an already-successful release tag just to include the checksum commit. Moving the tag rebuilds artifacts and can change the checksums again. Publish Hex from the commit that contains the final `checksum.exs`.

### 6. Smoke-test The Precompiled Path

In a separate scratch directory, verify that a consumer can compile the package without building the NIF from source.

```sh
mix new onnxruntime_smoke
cd onnxruntime_smoke
```

Add the dependency to `mix.exs`:

```elixir
{:onnxruntime, path: "../onnxruntime-elixir"}
```

Then compile it:

```sh
mix deps.get
mix deps.compile onnxruntime --force
```

This should download and restore a precompiled tarball for the current target when one is available. The logs should include `Downloading precompiled NIF` or reuse a cached precompiled archive, and should not run the project `Makefile` for the NIF build.

After the Hex package is published, run a second smoke test using the Hex dependency instead of the local path:

```elixir
{:onnxruntime, "~> 0.1.0-rc.1"}
```

### 7. Verify Source Fallback

Source fallback should continue to work for unsupported targets or when precompiled artifacts are unavailable. In a scratch project, force the fallback path with `elixir_make` config:

```elixir
# config/config.exs
import Config

config :elixir_make, :force_build, onnxruntime: true
```

Then recompile the dependency:

```sh
mix deps.compile onnxruntime --force
```

A source build requires:

- a C++17 compiler
- `make`
- network access for `scripts/fetch_onnxruntime.sh`, or `ONNXRUNTIME_DIR` pointing to an existing ONNX Runtime install

The build should still pass the project test suite after fallback compilation.

### 8. Publish To Hex

Hex publishing requires local Hex authentication or a valid `HEX_API_KEY`.

If using GitHub to sign in to hex.pm, set a Hex account password first:

```sh
mix hex.user reset_password account
```

Then authenticate this machine:

```sh
mix hex.user auth --key-name onnxruntime-elixir-release
```

Finally publish from the commit that contains the final `checksum.exs`:

```sh
mix hex.publish --yes
```

Hex releases are immutable. Confirm the package version, files, checksums, and GitHub assets before publishing.

## Updating The Precompile Matrix

Adding a new target means updating both the project configuration and CI:

1. Add the compiler target to `cc_precompiler()` in `mix.exs`.
2. Add the required runner or system packages to `.github/workflows/precompile.yml`.
3. Confirm the target has matching official ONNX Runtime CPU archives, or update `scripts/fetch_onnxruntime.sh` to support it.
4. Run the release process again and regenerate `checksum.exs`.

Removing a target is the inverse. Do not delete artifacts from older GitHub releases because consumers pinned to older package versions may still need those URLs.

## Source Build Fallback

Consumers reach source build fallback when:

1. Their target tuple or NIF version is not listed in `checksum.exs`.
2. The matching GitHub Release artifact is unavailable.
3. They set `config :elixir_make, :force_build, onnxruntime: true`.
4. They intentionally override the precompile URL or local build environment.

`elixir_make` also forces source builds for versions whose prerelease segment contains `dev`. Release candidates such as `0.1.0-rc.1` are still eligible for precompiled downloads.

Fallback is supported, but it is slower and depends on the local C++ build environment. The precompiled artifacts are an optimization, not the only supported installation path.

## Common Failure Modes

- `checksum mismatch` during install: the GitHub Release artifact changed after `checksum.exs` was generated. Regenerate and republish checksums in the next package release.
- `no precompiled NIF available`: the consumer target or NIF version is outside the current artifact matrix. Use source build fallback or add the target in the next release.
- GitHub Release upload fails with `Resource not accessible by integration`: ensure `.github/workflows/precompile.yml` has `permissions: contents: write`.
- Linux cross-compile fails: verify `gcc-aarch64-linux-gnu` and `g++-aarch64-linux-gnu` are installed in the Linux workflow job.
- Old Linux/glibc failures: the Linux artifacts are built on the configured GitHub runner image. If users report older distro failures, consider moving Linux builds to an older compatible container or manylinux-style environment.
- Duplicate or missing release assets: each matrix cell uploads to the same GitHub Release. Check that artifact filenames are unique by NIF version, target, and package version.


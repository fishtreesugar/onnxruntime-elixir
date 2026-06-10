#!/usr/bin/env bash
set -euo pipefail

version="${1:?version required}"
vendor_dir="${2:?vendor dir required}"
target="${3:-}"

host_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
host_arch="$(uname -m)"
target="${target:-${CC_PRECOMPILER_CURRENT_TARGET:-}}"
resolved_target="${target:-$host_os-$host_arch}"

case "$resolved_target" in
  *x86_64*darwin*|darwin-x86_64)
    asset="onnxruntime-osx-x86_64-${version}.tgz"
    ;;
  *aarch64*darwin*|*arm64*darwin*|darwin-arm64)
    asset="onnxruntime-osx-arm64-${version}.tgz"
    ;;
  *x86_64*linux*|linux-x86_64)
    asset="onnxruntime-linux-x64-${version}.tgz"
    ;;
  *aarch64*linux*|*arm64*linux*|linux-aarch64|linux-arm64)
    asset="onnxruntime-linux-aarch64-${version}.tgz"
    ;;
  *)
    echo "Unsupported ONNX Runtime target: $resolved_target" >&2
    echo "Set ORT_INCLUDE_DIR and ORT_LIB_DIR to use a custom ONNX Runtime build." >&2
    exit 1
    ;;
esac

version_dir="${vendor_dir}/${version}"
archive="${version_dir}/${asset}"
extract_dir="${version_dir}/${asset%.tgz}"
target_dir="${version_dir}/${resolved_target}"
url="https://github.com/microsoft/onnxruntime/releases/download/v${version}/${asset}"

mkdir -p "$version_dir"

if [ ! -f "$archive" ]; then
  echo "Downloading ${url}"
  curl --fail --location --show-error "$url" --output "$archive"
fi

if [ ! -d "$extract_dir" ]; then
  tar -xzf "$archive" -C "$version_dir"
fi

rm -f "$target_dir"
ln -s "$(basename "$extract_dir")" "$target_dir"

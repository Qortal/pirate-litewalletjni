#!/usr/bin/env bash
set -euo pipefail

# macOS build script for pirate-litewalletjni.
# Builds OpenSSL and Rust cdylib for x86_64-apple-darwin and aarch64-apple-darwin.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_DIR="${REPO_ROOT}/src"

HOST_ARCH="$(uname -m)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

num_jobs() {
  sysctl -n hw.ncpu
}

build_openssl() {
  OPENSSL_VERSION="1.1.1e"
  OPENSSL_DIRNAME="openssl-${OPENSSL_VERSION}"
  OPENSSL_EXT="tar.gz"
  OPENSSL_FILENAME="${OPENSSL_DIRNAME}.${OPENSSL_EXT}"
  OPENSSL_URL_PREFIX="https://www.openssl.org/source/old/1.1.1/"
  OPENSSL_URL="${OPENSSL_URL_PREFIX}${OPENSSL_FILENAME}"

  if [ ! -f "${OPENSSL_FILENAME}" ]; then
    curl -fL "${OPENSSL_URL}" -o "${OPENSSL_FILENAME}"
  fi
  if ! gzip -t "${OPENSSL_FILENAME}" >/dev/null 2>&1; then
    echo "OpenSSL archive looks invalid, re-downloading..."
    rm -f "${OPENSSL_FILENAME}"
    curl -fL "${OPENSSL_URL}" -o "${OPENSSL_FILENAME}"
  fi
  if [ ! -d "${OPENSSL_DIRNAME}" ]; then
    tar xvf "${OPENSSL_FILENAME}"
  fi

  if [ ! -d "${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}" ]; then
    cd "${OPENSSL_DIRNAME}"

    if [ -f "Makefile" ]; then
      make clean || true
      make distclean || true
    fi

    INSTALL_DIR="$(pwd)/${OPENSSL_DIRNAME}/${ARCH}"
    export CC="clang"
    export SDKROOT
    export CFLAGS="${OPENSSL_CFLAGS} -isysroot ${SDKROOT}"
    export LDFLAGS="${OPENSSL_LDFLAGS} -isysroot ${SDKROOT}"

    if [ -z "${OPENSSL_ARCH:-}" ]; then
      echo "OPENSSL_ARCH is not set; cannot configure OpenSSL."
      exit 1
    fi
    ./Configure "${OPENSSL_ARCH}" --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}/ssl"
    make -j"$(num_jobs)"
    make -j"$(num_jobs)" install
    cd "${SCRIPT_DIR}"
  fi
}

build_rustlib() {
  export OPENSSL_STATIC=yes
  export OPENSSL_LIB_DIR="${SCRIPT_DIR}/${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}/lib"
  export OPENSSL_INCLUDE_DIR="${SCRIPT_DIR}/${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}/include"

  rustup target add "${RUST_ARCH}"
  rustup show

  cargo build --manifest-path "${SCRIPT_DIR}/Cargo.toml" --target "${RUST_ARCH}" --release
}

build() {
  local ARCH=$1

  echo "Building ${ARCH} architecture..."

  if [ "${ARCH}" == "aarch64-apple-darwin" ]; then
    export RUST_ARCH="aarch64-apple-darwin"
    export OPENSSL_ARCH="darwin64-arm64-cc"
    export OPENSSL_CFLAGS="-arch arm64 -target arm64-apple-macos11"
    export OPENSSL_LDFLAGS="-arch arm64 -target arm64-apple-macos11"
  elif [ "${ARCH}" == "x86_64-apple-darwin" ]; then
    export RUST_ARCH="x86_64-apple-darwin"
    export OPENSSL_ARCH="darwin64-x86_64-cc"
    export OPENSSL_CFLAGS="-arch x86_64 -target x86_64-apple-macos10.13"
    export OPENSSL_LDFLAGS="-arch x86_64 -target x86_64-apple-macos10.13"
  else
    echo "Unknown architecture: ${ARCH}"
    exit 1
  fi
  if [ -z "${OPENSSL_ARCH:-}" ]; then
    echo "OPENSSL_ARCH is empty for ${ARCH}"
    exit 1
  fi

  if [ "${HOST_ARCH}" == "x86_64" ] && [ "${ARCH}" == "aarch64-apple-darwin" ]; then
    echo "Host is Intel; cross-compiling OpenSSL for arm64 using SDK: ${SDKROOT}"
  fi

  build_openssl
  build_rustlib
}

build "aarch64-apple-darwin"
build "x86_64-apple-darwin"

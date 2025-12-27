#!/bin/bash

set -euo pipefail

# Resolve script directory robustly (works even if sourced).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

function build_openssl {
    # Build openssl
    OPENSSL_VERSION="1.1.1e"
    OPENSSL_DIRNAME="openssl-${OPENSSL_VERSION}"
    OPENSSL_EXT="tar.gz"
    OPENSSL_FILENAME="${OPENSSL_DIRNAME}.${OPENSSL_EXT}"
    OPENSSL_URL_PREFIX="https://www.openssl.org/source/old/1.1.1/"
    OPENSSL_URL="${OPENSSL_URL_PREFIX}${OPENSSL_FILENAME}"

    # Download (retry if a previous attempt left an HTML error page)
    if [ ! -f "${OPENSSL_FILENAME}" ]; then
        curl -fL "${OPENSSL_URL}" -o "${OPENSSL_FILENAME}"
    fi
    if ! gzip -t "${OPENSSL_FILENAME}" >/dev/null 2>&1; then
        echo "OpenSSL archive looks invalid, re-downloading..."
        rm -f "${OPENSSL_FILENAME}"
        curl -fL "${OPENSSL_URL}" -o "${OPENSSL_FILENAME}"
    fi
    # Extract
    if [ ! -d "${OPENSSL_DIRNAME}" ]; then
        tar xvf "${OPENSSL_FILENAME}"
    fi
    # Build
    if [ ! -d "${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}" ]; then
        cd "${OPENSSL_DIRNAME}"

        chmod +x config
        ./config

        make clean
        make distclean

        if [ -n "${TOOLCHAIN:-}" ]; then
            export PATH=${TOOLCHAIN}:${TOOLCHAIN}/bin:$TOOLCHAIN/${ARCH}/bin:$PATH
        fi

        INSTALL_DIR=$(pwd)/${OPENSSL_DIRNAME}/${ARCH}

        ./Configure --prefix=${INSTALL_DIR} --openssldir=${INSTALL_DIR}/ssl ${OPENSSL_ARCH}
        make -j$(nproc)
        make -j$(nproc) install
        cd ..
    fi
}

function build_rustlib {
    # Build rustlib
    export OPENSSL_STATIC=yes
    export OPENSSL_LIB_DIR="${SCRIPT_DIR}/${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}/lib"
    export OPENSSL_INCLUDE_DIR="${SCRIPT_DIR}/${OPENSSL_DIRNAME}/${OPENSSL_DIRNAME}/${ARCH}/include"

    rustup target add ${RUST_ARCH}
    rustup component add rustfmt --toolchain 1.71.1-x86_64-unknown-linux-gnu
    rustup show

    cargo build --manifest-path "${SCRIPT_DIR}/Cargo.toml" --target ${RUST_ARCH} --release
}

function build {
    local ARCH=$1

    echo "Building ${ARCH} architecture..."

    if [ "$ARCH" == "arm-linux-gnueabihf" ]
    then
        export RUST_ARCH="arm-unknown-linux-gnueabihf"
        export OPENSSL_ARCH="linux-generic32"
        export TOOLCHAIN="/opt/arm-rpi-4.9.3-linux-gnueabihf"
        export AR=${TOOLCHAIN}/bin/arm-linux-gnueabihf-ar
        export CC=${TOOLCHAIN}/bin/arm-linux-gnueabihf-gcc

    elif [ "$ARCH" == "aarch64-linux-gnu" ]
    then
        export RUST_ARCH="aarch64-unknown-linux-gnu"
        export OPENSSL_ARCH="linux-aarch64"
        # Prefer system cross toolchain if installed; fall back to the old /opt path.
        if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
            export TOOLCHAIN=""
            export AR="aarch64-linux-gnu-ar"
            export CC="aarch64-linux-gnu-gcc"
        else
            export TOOLCHAIN="/opt/arm/9/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu"
            export AR=${TOOLCHAIN}/bin/aarch64-none-linux-gnu-ar
            export CC=${TOOLCHAIN}/bin/aarch64-none-linux-gnu-gcc
        fi

    elif [ "$ARCH" == "x86_64-linux" ]
    then
        export RUST_ARCH="x86_64-unknown-linux-gnu"
        export OPENSSL_ARCH="linux-x86_64"
        export TOOLCHAIN=""

    elif [ "$ARCH" == "x86_64-w64-mingw32" ]
    then
        export RUST_ARCH="x86_64-pc-windows-gnu"
        export OPENSSL_ARCH="mingw64"
        export TOOLCHAIN="/etc/alternatives"
        export AR=${TOOLCHAIN}/x86_64-w64-mingw32-gcc-ar
        export CC=${TOOLCHAIN}/x86_64-w64-mingw32-gcc
        export WINDRES=x86_64-w64-mingw32-windres
    fi

    build_openssl
    build_rustlib
}

build "x86_64-linux"
build "aarch64-linux-gnu"
build "x86_64-w64-mingw32"
#build "arm-linux-gnueabihf" # Library doesn't support 32bit

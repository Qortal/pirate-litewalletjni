# Pirate Chain LiteWalletJNI Build System

Based on code from <https://github.com/PirateNetwork/cordova-plugin-litewallet>
Adapted in July 2022 by Qortal dev team.
Further adapted by Qortal development team for automated Qortal builds in 2025.

## Overall Details

In order to fully build the Qortal binaries required, you must first build the lightwallet-cli ensuring it is updated, updating the repo if necessary.
Then you will add the repo's commit hash into cargo.toml so that rust will have the updated code in the cli repo.
(<https://github.com/Qortal/piratewallet-light-cli>)

### Toolchain

This repo is pinned to Rust 1.71.1 via `src/rust-toolchain`. Native builds require `protoc`
(the `protobuf-compiler` package) on your PATH.

### Native Builds

```bash
cd src/
cargo build --release
ls -l target/release
```

### Ubuntu24 native cross-compilation builds

New scripts in 'src/main' will now cross-compile all binaries for aarch, and linux.
There are 3 scripts now:

- **build-setup-ubuntu.sh** - This script does the required installations for cross-compilation natively on ubuntu 24+.
- **build-cross-ubuntu.sh** - This script builds the required binaries (all but Mac).
- **bundle.sh** - This script creates the final output files required for Qortal ARRR support.

With these scripts you will end up with all binaries (other than Mac - see below) required to be published to QDN, for full ARRR cross-chain trading support.
**NOTE** - bundle script is best-effort and doesn't yet guarantee all required files. See below for normally QDN-published binaries/files list.

### QDN-Published Binaries / File List

The following files are published directly to QDN (with the signatures in Qortal repo) in order for users to obtain/run the ARRR clients on their individual architectures:

**saplingspend_base64** (≈ 63.9 MB)

Type: `Text`
Purpose:
`Base64-encoded Sapling spend proving key.`
`Required for creating shielded (private) transactions on ARRR. Without this file, spends cannot be constructed.`

**saplingoutput_base64** (≈ 4.8 MB)

Type: `Text`
Purpose:
`Base64-encoded Sapling output proving key.`
`Used to create shielded outputs (notes). Also mandatory for shielded transactions.`

**coinparams.json** (≈ 262 bytes)

Type: `JSON`
Purpose:
`Network/coin-specific parameters for Pirate Chain (ARRR).`
`Defines things like consensus or address-related constants that the litewallet/JNI layer needs to interpret chain data correctly.`

**librust-linux-x86_64.so** (≈ 19.2 MB)

Type: `ELF shared library`
Purpose:
`JNI Rust backend compiled for Linux x86_64.`
`Loaded by Qortal Core to provide ARRR litewallet functionality on standard Linux desktops/servers.`

**librust-linux-aarch64.so** (≈ 18.9 MB)

Type: `ELF shared library`
Purpose:
`JNI Rust backend compiled for Linux ARM64 (aarch64).`
`Used on ARM servers, SBCs, and ARM laptops.`

**librust-windows-x86_64.dll**(≈ 9.5 MB)

Type: `Windows DLL`
Purpose:
`JNI Rust backend compiled for Windows x86_64.`
`Loaded by Qortal Core on Windows systems.`

**librust-macos-x86_64.dylib** (≈ 10.0 MB)

Type: `macOS dynamic library`
Purpose:
`JNI Rust backend compiled for macOS Intel (x86_64).`
`Used by Qortal Core on macOS systems (Intel Macs).`

**version** (≈ 6 bytes)

Type: Text
Purpose:
`Simple version marker for the bundle.`
`Used for sanity checks, debugging, or ensuring Core and JNI are in sync.`

### Mac Builds

In order to build mac Binaries, you must be on a Mac computer. A **build-mac.sh** script is included that will handle the build process on a mac.
NOTE - the 'build-setup-ubuntu.sh' and 'build-cross-ubuntu.sh' scripts will NOT work on Mac.
Build script will do its best to determine mac architecture and cross-compile, but is not guaranteed to cross-compile perfectly.

### Cross Compilation via Docker

(NOTE - Docker cross-compilation has not been tested in new update Dec 26 2025)

```bash
cd src/
./build-docker.sh
./crosscompile.sh
ls -l target
```

# Pirate Chain LiteWalletJNI Build System
Based on code from https://github.com/PirateNetwork/cordova-plugin-litewallet<br />
Adapted in July 2022 by Qortal dev team<br /><br />

### Toolchain ###

This repo is pinned to Rust 1.71.1 via `src/rust-toolchain`. Native builds require `protoc`
(the `protobuf-compiler` package) on your PATH.


### Native Builds ###

```
cd src/
cargo build --release
ls -l target/release
```


### Cross Compilation via Docker ###

```
cd src/
./build-docker.sh
./crosscompile.sh
ls -l target
```

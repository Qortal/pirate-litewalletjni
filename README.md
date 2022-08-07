# Pirate Chain LiteWalletJNI Build System
Based on code from https://github.com/PirateNetwork/cordova-plugin-litewallet<br />
Adapted in July 2022 by Qortal dev team<br /><br />


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

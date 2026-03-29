# Nuntius

P2P file sharing for iOS. Send files directly to another device with no servers, no accounts, and no cloud.

Built with Swift and [iroh](https://github.com/n0-computer/iroh) for peer-to-peer networking.

## How it works

The sender picks files and gets a ticket code. The receiver enters the ticket and the files transfer directly between devices over an encrypted P2P connection.

## Build

**1. Build the Rust FFI library**

```bash
cd nuntius-ffi && ./build-ios.sh
```

**2. Open and run in Xcode**

```
Nuntius/Nuntius.xcodeproj
```

Requires Xcode and a physical iPhone (sideloading).

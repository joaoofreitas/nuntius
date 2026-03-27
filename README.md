# Nuntius

Peer-to-peer file sharing application with dual implementations:

- **iOS**: Native Swift app using iroh-ffi
- **Web**: Browser-based app using Rust WebAssembly + iroh

## Quick Start

### WebAssembly Version
```bash
# Install wasm-pack
curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Build WebAssembly
cd web && wasm-pack build --target web

# Start server
cd ../server && cargo run

# Open http://localhost:3030
```

### iOS Version
Requires Xcode installation (see setup instructions below).

## Project Structure

- `ios/` - Swift iOS application
- `web/` - Rust WebAssembly application
- `server/` - Static file server for web app
- `shared/` - Common utilities
- `docs/` - Documentation

Both versions use the iroh library for reliable P2P networking with automatic NAT traversal and end-to-end encryption.

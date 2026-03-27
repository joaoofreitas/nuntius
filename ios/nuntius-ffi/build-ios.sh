#!/bin/bash
# Build nuntius-ffi as a static library for iOS and generate Swift bindings.
# Run this from ios/nuntius-ffi/ before opening the Xcode project.

set -e

CRATE_NAME="nuntius_ffi"
TARGET="aarch64-apple-ios"
OUT_DIR="../Nuntius/Nuntius/Generated"

echo "Adding iOS target..."
rustup target add $TARGET

echo "Building release static lib..."
cargo build --release --target $TARGET

echo "Generating Swift bindings..."
cargo run --bin uniffi-bindgen generate \
    --library "target/$TARGET/release/lib${CRATE_NAME}.a" \
    --language swift \
    --out-dir "$OUT_DIR"

echo ""
echo "Done. Next steps in Xcode:"
echo "  1. Add target/$TARGET/release/lib${CRATE_NAME}.a to the project (Build Phases > Link Binary)"
echo "  2. Add $OUT_DIR/${CRATE_NAME}FFI.h to the bridging header or module map"
echo "  3. Add the generated $OUT_DIR/${CRATE_NAME}.swift to the target"

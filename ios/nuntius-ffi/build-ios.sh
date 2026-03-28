#!/bin/bash
# Build nuntius-ffi as a static library for iOS and generate Swift bindings.
# Run this from ios/nuntius-ffi/

set -e

XCODE=/Volumes/ExternalSSD/Applications/Xcode.app
CRATE=nuntius_ffi
TARGET=aarch64-apple-ios
OUT=../Nuntius/Nuntius/Generated

export DEVELOPER_DIR="$XCODE/Contents/Developer"
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)

echo "SDK: $SDKROOT"

rustup target add $TARGET

cargo build --release --target $TARGET

mkdir -p $OUT

cargo run --bin uniffi-bindgen generate \
    --library "target/$TARGET/release/lib${CRATE}.a" \
    --language swift \
    --out-dir "$OUT"

echo ""
echo "Outputs in $OUT:"
ls "$OUT"
echo ""
echo "In Xcode:"
echo "  1. Link: target/$TARGET/release/lib${CRATE}.a"
echo "  2. Add:  $OUT/${CRATE}.swift to the target"
echo "  3. Add:  $OUT/${CRATE}FFI.h to a module map or bridging header"

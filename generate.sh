#!/bin/bash
set -euo pipefail

# Resolve paths relative to this script so it works when invoked from either
# the Flutter repo root or the sibling ledger repo root.
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
LEDGER_PROTO_DIR="$SCRIPT_DIR/../ledger/protos"
OUT_DIR="$SCRIPT_DIR/lib/proto"

# Add pub-cache bin to PATH so protoc-gen-dart is found.
export PATH="$PATH:$HOME/.pub-cache/bin"

# Generate google types.
protoc --dart_out=grpc:"$OUT_DIR" \
  /usr/include/google/protobuf/timestamp.proto \
  /usr/include/google/protobuf/empty.proto

# Generate services and types from the sibling ledger repo.
protoc --dart_out=grpc:"$OUT_DIR" \
  -I"$LEDGER_PROTO_DIR" \
  "$LEDGER_PROTO_DIR"/services/*.proto \
  "$LEDGER_PROTO_DIR"/types/*.proto

echo "Proto generation complete!"

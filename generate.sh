#!/bin/bash

# Output directory
OUT_DIR="lib/proto"

# Generate google types
protoc --dart_out=grpc:$OUT_DIR /usr/include/google/protobuf/timestamp.proto /usr/include/google/protobuf/empty.proto

# Generate services and types
protoc --dart_out=grpc:$OUT_DIR -I../ledger/protos ../ledger/protos/services/*.proto ../ledger/protos/types/*.proto


echo "Proto generation complete!"

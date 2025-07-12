#!/bin/bash
set -e

# Build script for Status Bar Extension

echo "Building Status Bar Extension..."

mkdir -p bin
swiftc -o bin/statusbar-bin src/main.swift

if [ $? -eq 0 ]; then
    echo "Build successful! Executable created: statusbar-bin"
else
    echo "Build failed!"
    exit 1
fi 
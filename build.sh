#!/usr/bin/env bash
set -euo pipefail

# Automatically fetch the latest stable VIPS version if not set
if [ -z "${VIPS_VERSION:-}" ]; then
  echo "-----> Fetching latest libvips version from GitHub..."
  VIPS_VERSION=$(curl --fail --silent --show-error \
    https://api.github.com/repos/libvips/libvips/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"v([^"]+)".*/\1/')
fi

if [ -z "$VIPS_VERSION" ]; then
  echo "Error: Could not determine VIPS_VERSION" >&2
  exit 1
fi

echo "-----> Target Version: $VIPS_VERSION"

mkdir -p ./build/configurations
rm -f ./build/*.tar.bz2 ./build/*.tar.gz ./build/configurations/*.log

echo "-----> Building libvips $VIPS_VERSION"

docker buildx build --platform linux/amd64 \
  --build-arg VIPS_VERSION=${VIPS_VERSION} \
  --target exporter \
  --output type=local,dest=./build \
  -f "container/Dockerfile" container

echo "-----> Testing tarball integrity"
docker buildx build --platform linux/amd64 --progress=plain \
  -t libvips-test \
  -f container/Dockerfile.test .

echo "Done! Final artifact: build/scalingo.tar.bz2"
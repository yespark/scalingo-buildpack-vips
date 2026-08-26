#!/usr/bin/env bash
set -euo pipefail

# Target stack. One tarball per stack: the artifact only bundles what its base
# image lacks, so it is not portable from one Ubuntu release to another.
STACK="${STACK:-scalingo-24}"

case "$STACK" in
  scalingo-24 | scalingo-26) ;;
  *)
    echo "Error: unsupported STACK '$STACK' (expected scalingo-24 or scalingo-26)" >&2
    exit 1
    ;;
esac

BASE_IMAGE="${BASE_IMAGE:-scalingo/${STACK}:latest}"

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
echo "-----> Target Stack: $STACK ($BASE_IMAGE)"

mkdir -p ./build/configurations
# Scoped to this stack: building both in a row must not wipe the other artifact.
rm -f "./build/${STACK}.tar.bz2" "./build/configurations/${STACK}.config.log"

echo "-----> Building libvips $VIPS_VERSION"

docker buildx build --platform linux/amd64 \
  --build-arg VIPS_VERSION=${VIPS_VERSION} \
  --build-arg STACK=${STACK} \
  --build-arg BASE_IMAGE=${BASE_IMAGE} \
  --target exporter \
  --output type=local,dest=./build \
  -f "container/Dockerfile" container

echo "-----> Testing tarball integrity"
docker buildx build --platform linux/amd64 --progress=plain \
  -t "libvips-test-${STACK}" \
  --build-arg STACK=${STACK} \
  --build-arg BASE_IMAGE=${BASE_IMAGE} \
  -f container/Dockerfile.test .

echo "Done! Final artifact: build/${STACK}.tar.bz2"
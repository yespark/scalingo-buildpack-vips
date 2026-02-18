# CLAUDE.md

This file provides guidance to AI assistants and developers when working with code in this repository.

## Project Overview

This is a Scalingo buildpack that provides pre-compiled **libvips** binaries for the `scalingo-24` stack. It compiles libvips from source inside a Docker container based on `scalingo/scalingo-24:latest`, packages the results as a tarball, and vendors it into Scalingo apps at deploy time.

## Build & Test Commands

### Local Build

Build the libvips tarball (requires Docker with BuildKit):

```bash
# To build a specific version:
VIPS_VERSION=8.18.0 ./build.sh

# To build the latest stable version automatically:
./build.sh

```

This script uses `docker buildx` with the `--output` flag to export `build/scalingo.tar.gz` and `build/configurations/` directly to your host machine without needing a `docker cp` step.

### Test Validation

The build script automatically runs **`container/Dockerfile.test`**. This:

1. Simulates the actual Scalingo runtime environment.
2. Extracts the local tarball to `/app/vendor/vips`.
3. Sets up the exact environment variables used in production.
4. Installs `ruby-dev` and the `ruby-vips` gem to verify shared library linking.

## Architecture

This is a standard Scalingo/Heroku-style buildpack:

* **`bin/detect`**: Restricts usage to the `scalingo-24` stack (Ubuntu 24.04).
* **`bin/compile`**: Called during deploy. Extracts `build/scalingo.tar.gz` into `$BUILD_DIR/vendor/vips` and generates a `.profile.d/vips.sh` script to set up `LD_LIBRARY_PATH` and other env vars for the app runtime.
* **`build.sh`**: Orchestrates the Docker build. It fetches the latest version from the GitHub API if `VIPS_VERSION` is not provided.
* **`.github/workflows/build-vips.yml`**: Automates the build on a weekly schedule or on push, committing updated binaries back to the repo.

## Docker Build Pipeline (`container/Dockerfile`)

The build process is split into two stages:

1. **Builder Stage**:
* Based on `scalingo/scalingo-24:latest`.
* Uses `--mount=type=cache` for `apt` packages to speed up rebuilds.
* Installs build tools (`meson`, `ninja`, `pkg-config`) and system headers for libraries already present on the Scalingo stack (glib, webp, jpeg, tiff, etc.).
* Compiles libvips into a clean, isolated prefix (`/opt/vips-build`).
* Strips symbols from binaries to reduce slug size.


2. **Exporter Stage**: A `scratch` image that only contains the resulting tarball and config logs, allowing for clean extraction.

## Key Details

* **Prefix**: The library is built to be relocatable, but the buildpack defaults to `/app/vendor/vips`.
* **Optimization**: Obscure formats (`radiance`, `analyze`) and `introspection` are disabled to keep the binary lean.
* **Compatibility**: Modules are disabled (`-Dmodules=disabled`) to ensure stability with the `ruby-vips` gem.
* **Artifacts**: `build/configurations/scalingo.config.log` contains the full feature set enabled in the current build (visible via `vips --vips-config`).

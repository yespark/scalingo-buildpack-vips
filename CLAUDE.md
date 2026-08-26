# CLAUDE.md

This file provides guidance to AI assistants and developers when working with code in this repository.

## Project Overview

This is a Scalingo buildpack that provides pre-compiled **libvips** binaries for the `scalingo-24` and `scalingo-26` stacks. It compiles libvips from source inside a Docker container based on that stack's image (`scalingo/scalingo-24:latest` or `scalingo/scalingo-26:latest`), packages the results as a tarball, and vendors it into Scalingo apps at deploy time.

**One tarball per stack, never interchangeable.** The artifact bundles only the shared libraries missing from its own base image, so it is bound to that image's ABI. Concretely, a scalingo-24 tarball on scalingo-26 dies at load time on `libMagickCore-6.Q16.so.7` (26.04 ships ImageMagick 7) and `librsvg-2.so.2` (26.04 ships no rsvg at all). `ruby-vips` loads libvips by FFI at boot, so the app does not start.

## Build & Test Commands

### Local Build

Build the libvips tarball (requires Docker with BuildKit):

```bash
# Latest stable version, scalingo-24 (default stack):
./build.sh

# Target the other stack:
STACK=scalingo-26 ./build.sh

# Pin a version:
VIPS_VERSION=8.18.0 STACK=scalingo-26 ./build.sh
```

This script uses `docker buildx` with the `--output` flag to export `build/<stack>.tar.bz2` and `build/configurations/<stack>.config.log` directly to your host machine without needing a `docker cp` step. `STACK` selects the base image (`BASE_IMAGE` overrides it) and names the artifacts, so both stacks can be built in a row without clobbering each other.

### Test Validation

The build script automatically runs **`container/Dockerfile.test`**. This:

1. Simulates the actual Scalingo runtime environment.
2. Extracts the local tarball to `/app/vendor/vips`.
3. Sets up the exact environment variables used in production.
4. Installs `ruby-dev` and the `ruby-vips` gem to verify shared library linking.

## Architecture

This is a standard Scalingo/Heroku-style buildpack:

* **`bin/detect`**: Restricts usage to `scalingo-24` and `scalingo-26`.
* **`bin/compile`**: Called during deploy. Accepts `$1` (BUILD_DIR), `$2` (CACHE_DIR), and optionally `$3` (ENV_DIR). Resolves the stack from `$STACK` (falling back to `/etc/os-release`), downloads `<stack>.tar.bz2` from the release, extracts it into `$BUILD_DIR/vendor/vips` and generates a `.profile.d/vips.sh` script to set up `LD_LIBRARY_PATH` and other env vars for the app runtime. Supports version pinning via `VIPS_VERSION` in `$ENV_DIR`. On `scalingo-24` only, it falls back to the legacy unsuffixed `scalingo.tar.bz2` when a release predates the multi-stack split; on `scalingo-26` a missing asset is a hard error rather than a silent substitution.
* **`build.sh`**: Orchestrates the Docker build for one stack (`STACK`, default `scalingo-24`). It fetches the latest version from the GitHub API if `VIPS_VERSION` is not provided.
* **`.github/workflows/build-vips.yml`**: Builds both stacks in a matrix (weekly, on `workflow_dispatch`, and on every pull request), then publishes a single release carrying both tarballs. Pull requests build and test but never release.
* **`.sclng/metadata.toml`**: Scalingo ecosystem buildpack metadata.

## Docker Build Pipeline (`container/Dockerfile`)

The build process is split into three stages:

The target image comes from the `BASE_IMAGE` build arg (`scalingo/<stack>:latest`), and `STACK` names the exported artifact.

1. **Base-Snapshot Stage**: Runs on the clean base image and records every `.so` filename present *before* build dependencies are installed. This inventory is saved to `/tmp/base-libs.txt`.

2. **Builder Stage**:
* Based on the same base image.
* Uses `--mount=type=cache` for `apt` packages to speed up rebuilds.
* Installs build tools (`meson`, `ninja`, `pkg-config`) and system headers for libraries already present on the Scalingo stack (glib, webp, jpeg, tiff, etc.).
* Compiles libvips into a clean, isolated prefix (`/opt/vips-build`).
* Strips symbols from binaries to reduce slug size.
* **Bundles runtime shared libraries**: Uses `ldd` on `libvips.so` and diffs the results against the base-snapshot to copy any shared libraries that aren't on the base image (e.g., poppler, orc, openjp2) into the prefix's `lib/` directory. This makes the tarball self-contained — no extra `apt-get install` is needed at deploy time.

3. **Exporter Stage**: A `scratch` image that only contains the resulting tarball and config logs, allowing for clean extraction.

## Runtime Configuration

* **`VIPS_VERSION`**: Set this env var on your Scalingo app to pin `bin/compile` to a specific release (e.g., `scalingo env-set VIPS_VERSION=8.18.0`). When set, the buildpack fetches `/releases/tags/v${VIPS_VERSION}` instead of `/releases/latest`. The existing cache invalidation (VERSION file comparison) handles version switches automatically.
* **`BUILDPACK_DEBUG`**: Set this env var to enable `set -x` tracing in both `bin/detect` and `bin/compile` for troubleshooting deploy issues.

## Key Details

* **Prefix**: The library is built to be relocatable, but the buildpack defaults to `/app/vendor/vips`.
* **Optimization**: Obscure formats (`radiance`, `analyze`) and `introspection` are disabled to keep the binary lean.
* **Compatibility**: Modules are disabled (`-Dmodules=disabled`) to ensure stability with the `ruby-vips` gem.
* **Artifacts**: `build/configurations/<stack>.config.log` contains the full feature set enabled in the current build (visible via `vips --vips-config`).
* **Build dependencies are stack-sensitive**: meson silently disables a loader whose dev package is missing, and the build stays green. `librsvg2-dev` is in the apt list for exactly that reason — Ubuntu 24.04 carries librsvg on the base image, 26.04 does not, so without it scalingo-26 would ship a libvips with no SVG support. Same trap for any future stack: **diff the two `<stack>.config.log` files before releasing**, never trust a green build alone.
* **ImageMagick**: dev files ship on both base images (6.9.12 on 24.04, 7.1.2 on 26.04), so libvips links whichever is there and the magick loader follows the stack. Nothing to pin.

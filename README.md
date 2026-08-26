# scalingo-buildpack-vips

[![stack](https://img.shields.io/badge/stack-scalingo--24%20%7C%20scalingo--26-6C3BF5)](https://doc.scalingo.com/platform/internals/stacks/scalingo-26-stack)
[![release](https://img.shields.io/github/v/release/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/releases/latest)
[![release date](https://img.shields.io/github/release-date/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/releases/latest)
[![build](https://img.shields.io/github/actions/workflow/status/yespark/scalingo-buildpack-vips/build-vips.yml?label=build)](https://github.com/yespark/scalingo-buildpack-vips/actions/workflows/build-vips.yml)

A [Scalingo buildpack](https://doc.scalingo.com/platform/deployment/buildpacks/custom) that provides pre-compiled [libvips](https://www.libvips.org/) binaries.

## Usage

Add this buildpack **before** your language buildpack in a `.buildpacks` file at the root of your project:

```
https://github.com/yespark/scalingo-buildpack-vips
https://github.com/Scalingo/ruby-buildpack
```

The buildpack automatically downloads a pre-built tarball from [GitHub Releases](https://github.com/yespark/scalingo-buildpack-vips/releases), extracts it to `/app/vendor/vips`, and configures the environment for both runtime and subsequent buildpacks.

## Stacks

`scalingo-24` and `scalingo-26` are supported, with **one tarball per stack** (`scalingo-24.tar.bz2`, `scalingo-26.tar.bz2`). `bin/compile` picks the right one from `$STACK`; nothing to configure.

The tarballs are not interchangeable. Each one only bundles the shared libraries missing from *its* base image, so a scalingo-24 build dropped on scalingo-26 fails to load — Ubuntu 26.04 ships ImageMagick 7 instead of 6 and no rsvg at all:

```
/app/vendor/vips/bin/vips: error while loading shared libraries:
libMagickCore-6.Q16.so.7: cannot open shared object file
```

Since `ruby-vips` loads libvips through FFI at boot, that mismatch stops the app from starting. `bin/compile` therefore refuses to substitute one stack's tarball for another.

**Exported variables:**
- `PATH`
- `LD_LIBRARY_PATH`
- `LIBRARY_PATH`
- `PKG_CONFIG_PATH`
- `INCLUDE_PATH`
- `CPATH`
- `CPPPATH`
- `LIBHEIF_PLUGIN_PATH`.

This allows subsequent buildpacks (Ruby, Python, etc.) to compile native extensions against libvips without additional configuration.

## Configuration

| Variable | Description |
|---|---|
| `VIPS_VERSION` | Pin a specific libvips release (e.g. `scalingo env-set VIPS_VERSION=8.18.0`). Defaults to latest stable release. Pre-release versions (rc, alpha, beta) are rejected. |
| `BUILDPACK_DEBUG` | Enable `set -x` tracing in `bin/detect` and `bin/compile` for troubleshooting deploys. |

## Supported formats

JPEG, PNG, WebP, TIFF, SVG, PDF, HEIF/AVIF, OpenEXR, and JPEG 2000. GIF creation is disabled.
See `build/configurations/<stack>.config.log` for the full feature list, one per stack.

That log is the review gate when touching the build: a loader that disappears (SVG, magick, PDF, HEIF) leaves the build green and only shows up there. Compare the two stacks' logs before publishing a release.

## Building locally

Requires Docker with BuildKit.

```bash
# Latest stable version, scalingo-24 (default)
./build.sh

# scalingo-26
STACK=scalingo-26 ./build.sh

# Specific version
VIPS_VERSION=8.18.0 STACK=scalingo-26 ./build.sh
```

This builds the tarball inside a Docker container matching the target stack and runs the full test suite automatically, including format validation, Active Storage variant pipelines, and the upstream `image_processing` gem tests.

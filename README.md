# scalingo-buildpack-vips

[![stack](https://img.shields.io/badge/stack-scalingo--24-6C3BF5)](https://doc.scalingo.com/platform/stacks/scalingo-24)
[![release](https://img.shields.io/github/v/release/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/releases/latest)
[![release date](https://img.shields.io/github/release-date/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/releases/latest)
[![build](https://img.shields.io/github/actions/workflow/status/yespark/scalingo-buildpack-vips/build-vips.yml?label=build)](https://github.com/yespark/scalingo-buildpack-vips/actions/workflows/build-vips.yml)
[![last commit](https://img.shields.io/github/last-commit/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/commits/main)
[![issues](https://img.shields.io/github/issues/yespark/scalingo-buildpack-vips)](https://github.com/yespark/scalingo-buildpack-vips/issues)

A [Scalingo buildpack](https://doc.scalingo.com/platform/deployment/buildpacks/custom) that provides pre-compiled [libvips](https://www.libvips.org/) binaries for the `scalingo-24` stack.

## Usage

Add this buildpack **before** your language buildpack in a `.buildpacks` file at the root of your project:

```
https://github.com/yespark/scalingo-buildpack-vips
https://github.com/Scalingo/ruby-buildpack
```

The buildpack automatically downloads a pre-built tarball from [GitHub Releases](https://github.com/yespark/scalingo-buildpack-vips/releases), extracts it to `/app/vendor/vips`, and configures the environment for both runtime and subsequent buildpacks.

**Exported variables:** `PATH`, `LD_LIBRARY_PATH`, `LIBRARY_PATH`, `PKG_CONFIG_PATH`, `INCLUDE_PATH`, `CPATH`, `CPPPATH`, and `LIBHEIF_PLUGIN_PATH`. This allows subsequent buildpacks (Ruby, Python, etc.) to compile native extensions against libvips without additional configuration.

## Configuration

| Variable | Description |
|---|---|
| `VIPS_VERSION` | Pin a specific libvips release (e.g. `scalingo env-set VIPS_VERSION=8.18.0`). Defaults to latest stable release. Pre-release versions (rc, alpha, beta) are rejected. |
| `BUILDPACK_DEBUG` | Enable `set -x` tracing in `bin/detect` and `bin/compile` for troubleshooting deploys. |

## Supported formats

JPEG, PNG, WebP, TIFF, SVG, PDF, HEIF/AVIF, OpenEXR, and JPEG 2000. GIF creation is disabled (`cgif=disabled`). See `build/configurations/scalingo.config.log` for the full feature list.

## Building locally

Requires Docker with BuildKit.

```bash
# Latest stable version
./build.sh

# Specific version
VIPS_VERSION=8.18.0 ./build.sh
```

This builds the tarball inside a Docker container matching the `scalingo-24` stack and runs the full test suite automatically, including format validation, Active Storage variant pipelines, and the upstream `image_processing` gem tests.

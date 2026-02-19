# scalingo-buildpack-vips

A [Scalingo buildpack](https://doc.scalingo.com/platform/deployment/buildpacks/custom) that provides pre-compiled [libvips](https://www.libvips.org/) binaries for the `scalingo-24` stack.

## Usage

Add this buildpack **before** your language buildpack in a `.buildpacks` file at the root of your project:

```
https://github.com/yespark/scalingo-buildpack-vips
https://github.com/Scalingo/ruby-buildpack
```

The buildpack exports `PKG_CONFIG_PATH`, `LIBRARY_PATH`, `INCLUDE_PATH`, and other variables so subsequent buildpacks (Ruby, Python, etc.) can compile native extensions against libvips.

## Configuration

| Variable | Description |
|---|---|
| `VIPS_VERSION` | Pin a specific libvips release (e.g. `scalingo env-set VIPS_VERSION=8.18.0`). Defaults to latest. |
| `BUILDPACK_DEBUG` | Enable `set -x` tracing for troubleshooting deploys. |

## Supported formats

JPEG, PNG, WebP, TIFF, GIF, SVG, PDF, HEIF/AVIF, and more. See `build/configurations/scalingo.config.log` for the full feature list.

## Building locally

Requires Docker with BuildKit.

```bash
# Latest stable version
./build.sh

# Specific version
VIPS_VERSION=8.18.0 ./build.sh
```

This builds the tarball and runs the test suite automatically.

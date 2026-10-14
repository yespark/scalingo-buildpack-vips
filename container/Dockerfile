# syntax=docker/dockerfile:1

# Base image of the target stack. The tarball is NOT portable across stacks: it
# only bundles the libraries missing from this very image (see base-snapshot),
# so a scalingo-24 build fails to load on scalingo-26 and vice versa.
ARG BASE_IMAGE=scalingo/scalingo-24:latest

# Stage 0: Snapshot the base-image shared libraries (before build deps)
FROM ${BASE_IMAGE} AS base-snapshot
RUN find /usr/lib /lib -name "*.so*" -type f -o -name "*.so*" -type l \
    | xargs -r -n1 basename | sort -u > /tmp/base-libs.txt

# Stage 1: Build libvips
FROM ${BASE_IMAGE} AS builder

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Copy the base-image lib inventory (before apt-get adds build deps)
COPY --from=base-snapshot /tmp/base-libs.txt /tmp/base-libs.txt

# Install the build dependencies missing from the base image. The list is kept
# identical across stacks so the two builds stay comparable: a package already
# satisfied by the base image is a no-op here.
#
# librsvg2-dev matters on scalingo-26 only: Ubuntu 24.04 ships librsvg on the
# base image, Ubuntu 26.04 does not. Without it meson silently disables the SVG
# loader — the build stays green and SVG support disappears from the tarball.
#
# aom-tools is build-only: on 26.04 the AOM CMake config imports /usr/bin/aomdec,
# and libheif's configure step aborts when that file is missing.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    mkdir -p /var/log/apt && \
    apt-get update -qq -o Acquire::Retries=3 && \
    apt-get install -qq -o Acquire::Retries=3 -y --no-install-recommends \
      ninja-build \
      pkg-config \
      meson \
      glib-2.0-dev \
      libexpat1-dev \
      libpango1.0-dev \
      libpng-dev \
      libxml2-dev \
      libfftw3-dev \
      libpoppler-glib-dev \
      librsvg2-dev \
      libimagequant-dev \
      liborc-0.4-dev \
      cmake \
      libde265-dev \
      libx265-dev \
      libaom-dev \
      aom-tools

ARG VIPS_VERSION=8.18.0
# libvips >= 8.18.6 tags heifload UNTRUSTED when built against libheif < 1.23.2
# (critical CVEs), so Vips.block_untrusted(true) in image_processing stops HEIC
# decoding. Ubuntu ships an older libheif: build it from source into $PREFIX.
ARG LIBHEIF_VERSION=1.23.6
ARG LIBHEIF_SHA256=4484346dc5995319dbc11e3a1c35d0a2ec46511ce370900869337fd2c7033125
ARG PREFIX=/opt/vips-build
# Names the exported artifact, so both stacks can live side by side in build/
# and in a single GitHub release.
ARG STACK=scalingo-24
WORKDIR /usr/local/src

# Build libheif with its HEVC/AV1 codecs as plugins (cached unless LIBHEIF_VERSION changes)
RUN curl -sSLo libheif-${LIBHEIF_VERSION}.tar.gz https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz \
    && echo "${LIBHEIF_SHA256}  libheif-${LIBHEIF_VERSION}.tar.gz" | sha256sum -c - \
    && tar xf libheif-${LIBHEIF_VERSION}.tar.gz \
    && cmake -S libheif-${LIBHEIF_VERSION} -B libheif-build -G Ninja \
       -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_INSTALL_LIBDIR=lib \
       -DWITH_EXAMPLES=OFF -DBUILD_TESTING=OFF -DWITH_GDK_PIXBUF=OFF \
       -DWITH_LIBDE265=ON -DWITH_LIBDE265_PLUGIN=ON \
       -DWITH_X265=ON -DWITH_X265_PLUGIN=ON \
       -DWITH_AOM_DECODER=ON -DWITH_AOM_DECODER_PLUGIN=ON \
       -DWITH_AOM_ENCODER=ON -DWITH_AOM_ENCODER_PLUGIN=ON \
    && cmake --build libheif-build \
    && cmake --install libheif-build

# meson must resolve libheif from $PREFIX, never from a -dev package of the base image
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig

# Download and extract source (cached unless VIPS_VERSION changes)
RUN curl -sSLo vips-${VIPS_VERSION}.tar.xz https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz \
    && tar xf vips-${VIPS_VERSION}.tar.xz

# Configure (cached unless meson flags or installed deps change)
RUN cd vips-${VIPS_VERSION} \
    && meson setup build --prefix=$PREFIX --libdir=lib --buildtype=release \
       -Dradiance=false -Danalyze=false -Dcgif=disabled -Dmodules=disabled -Dintrospection=disabled

# Compile and install
RUN cd vips-${VIPS_VERSION}/build && meson compile && meson install

# Clean, bundle runtime deps, and create the artifact
RUN mkdir -p /export/configurations \
    && cd $PREFIX \
    && rm -rf bin/vipsprofile lib/*.a lib/python* \
    && find bin lib -type f \( -name "*.so*" -o -executable \) -exec strip --strip-unneeded {} + 2>/dev/null || true \
    # Bundle shared libraries that libvips needs but aren't on the base image.
    # Compare ldd output against the base-image snapshot to find extras.
    && export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}" \
    && ldd lib/libvips.so \
       | awk '/=>/ && $3 != "" {print $3}' \
       | while read -r sopath; do \
           case "$sopath" in ${PREFIX}/*) continue ;; esac; \
           soname=$(basename "$sopath"); \
           grep -qxF "$soname" /tmp/base-libs.txt || { cp -L "$sopath" lib/ && cd lib && ldconfig -l "$soname" 2>/dev/null; cd ..; }; \
         done \
    # Bundle libheif plugins (dynamically loaded, not caught by ldd)
    && mv lib/libheif lib/heif-plugins \
    && for plugin in lib/heif-plugins/*.so; do \
         ldd "$plugin" | awk '/=>/ && $3 != "" {print $3}' \
         | while read -r sopath; do \
             soname=$(basename "$sopath"); \
             grep -qxF "$soname" /tmp/base-libs.txt \
               || test -f lib/"$soname" \
               || cp -L "$sopath" lib/ ; \
           done; \
       done \
    && tar cjf "/export/${STACK}.tar.bz2" bin include lib \
    && echo "vips --vips-version" > "/export/configurations/${STACK}.config.log" \
    && $PREFIX/bin/vips --vips-version >> "/export/configurations/${STACK}.config.log" \
    && echo "libheif $(pkg-config --modversion libheif)" >> "/export/configurations/${STACK}.config.log" \
    && printf '\nvips --vips-config\n' >> "/export/configurations/${STACK}.config.log" \
    && $PREFIX/bin/vips --vips-config >> "/export/configurations/${STACK}.config.log"

# Stage 2: Exporter (copies files back to host via build.sh)
FROM scratch AS exporter
COPY --from=builder /export/ /

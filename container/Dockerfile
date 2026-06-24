# syntax=docker/dockerfile:1

# Stage 0: Snapshot the base-image shared libraries (before build deps)
FROM scalingo/scalingo-24:latest AS base-snapshot
RUN find /usr/lib /lib -name "*.so*" -type f -o -name "*.so*" -type l \
    | xargs -r -n1 basename | sort -u > /tmp/base-libs.txt

# Stage 1: Build libvips
FROM scalingo/scalingo-24:latest AS builder

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Copy the base-image lib inventory (before apt-get adds build deps)
COPY --from=base-snapshot /tmp/base-libs.txt /tmp/base-libs.txt

# Install only packages not already on the scalingo-24 base image
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
      libimagequant-dev \
      liborc-0.4-dev \
      libheif-dev \
      libheif-plugin-x265 \
      libheif-plugin-libde265

ARG VIPS_VERSION=8.18.0
ARG PREFIX=/opt/vips-build
WORKDIR /usr/local/src

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
    && cp -rL /usr/lib/x86_64-linux-gnu/libheif/plugins lib/heif-plugins \
    && for plugin in lib/heif-plugins/*.so; do \
         ldd "$plugin" | awk '/=>/ && $3 != "" {print $3}' \
         | while read -r sopath; do \
             soname=$(basename "$sopath"); \
             grep -qxF "$soname" /tmp/base-libs.txt \
               || test -f lib/"$soname" \
               || cp -L "$sopath" lib/ ; \
           done; \
       done \
    && tar cjf "/export/scalingo.tar.bz2" bin include lib \
    && echo "vips --vips-version" > "/export/configurations/scalingo.config.log" \
    && $PREFIX/bin/vips --vips-version >> "/export/configurations/scalingo.config.log" \
    && printf '\nvips --vips-config\n' >> "/export/configurations/scalingo.config.log" \
    && $PREFIX/bin/vips --vips-config >> "/export/configurations/scalingo.config.log"

# Stage 2: Exporter (copies files back to host via build.sh)
FROM scratch AS exporter
COPY --from=builder /export/ /

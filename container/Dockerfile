# syntax=docker/dockerfile:1
FROM scalingo/scalingo-24:latest AS builder

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install only packages not already on the scalingo-24 base image
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    mkdir -p /var/log/apt && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
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
      libheif-dev

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

# Clean and bundle the artifact
RUN mkdir -p /export/configurations \
    && cd $PREFIX \
    && rm -rf bin/vipsprofile lib/*.a lib/python* \
    && strip lib/libvips.so* \
    && tar czf "/export/scalingo.tar.gz" bin include lib \
    && export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}" \
    && echo "vips --vips-version" > "/export/configurations/scalingo.config.log" \
    && $PREFIX/bin/vips --vips-version >> "/export/configurations/scalingo.config.log" \
    && echo -e "\nvips --vips-config" >> "/export/configurations/scalingo.config.log" \
    && $PREFIX/bin/vips --vips-config >> "/export/configurations/scalingo.config.log"

# Stage 2: Exporter (copies files back to host via build.sh)
FROM scratch AS exporter
COPY --from=builder /export/ /

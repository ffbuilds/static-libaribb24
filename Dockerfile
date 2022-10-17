
# bump: libaribb24 /LIBARIBB24_VERSION=([\d.]+)/ https://github.com/nkoriyama/aribb24.git|*
# bump: libaribb24 after ./hashupdate Dockerfile LIBARIBB24 $LATEST
# bump: libaribb24 link "Release notes" https://github.com/nkoriyama/aribb24/releases/tag/$LATEST
ARG LIBARIBB24_VERSION=1.0.3
ARG LIBARIBB24_URL="https://github.com/nkoriyama/aribb24/archive/v$LIBARIBB24_VERSION.tar.gz"
ARG LIBARIBB24_SHA256=f61560738926e57f9173510389634d8c06cabedfa857db4b28fb7704707ff128

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBARIBB24_URL
ARG LIBARIBB24_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libaribb24.tar.gz ${LIBARIBB24_URL} && \
  echo "$LIBARIBB24_SHA256  libaribb24.tar.gz" | sha256sum --status -c - && \
  mkdir libaribb24 && \
  tar xf libaribb24.tar.gz -C libaribb24 --strip-components=1 && \
  rm libaribb24.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libaribb24/ /tmp/libaribb24/
WORKDIR /tmp/libaribb24
RUN \
  apk add --no-cache --virtual build \
    build-base autoconf automake libtool libpng-dev && \
  autoreconf -fiv && \
  ./configure --enable-static --disable-shared && \
  make -j$(nproc) && make install && \
  # Sanity tests
  pkg-config --exists --modversion --path aribb24 && \
  ar -t /usr/local/lib/libaribb24.a && \
  readelf -h /usr/local/lib/libaribb24.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBARIBB24_VERSION
COPY --from=build /usr/local/lib/pkgconfig/aribb24.pc /usr/local/lib/pkgconfig/aribb24.pc
COPY --from=build /usr/local/lib/libaribb24.a /usr/local/lib/libaribb24.a
COPY --from=build /usr/local/include/aribb24/ /usr/local/include/aribb24/

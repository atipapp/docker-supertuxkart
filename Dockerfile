# -----------
# Build stage
# -----------

FROM ubuntu:24.04 AS build
WORKDIR /stk

# Set stk version that should be built (git tag in supertuxkart/stk-code)
ENV VERSION=1.5

# Install build dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential \
        cmake \
        git \
        libcurl4-openssl-dev \
        libenet-dev \
        libssl-dev \
        libsqlite3-dev \
        pkg-config \
        subversion \
        zlib1g-dev \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Get code (tagged release) and assets (SVN trunk — stk-assets-release only
# publishes snapshots up to 1.1, so newer releases build against trunk).
RUN git clone --branch ${VERSION} --depth=1 https://github.com/supertuxkart/stk-code.git
RUN svn checkout --non-interactive --trust-server-cert \
        https://svn.code.sf.net/p/supertuxkart/code/stk-assets stk-assets

# Build server-only binary
RUN mkdir stk-code/cmake_build && \
    cd stk-code/cmake_build && \
    cmake .. -DSERVER_ONLY=ON -DUSE_SYSTEM_ENET=ON && \
    make -j"$(nproc)" && \
    make install

# SERVER_ONLY install still drops the full client asset tree into
# /usr/local/share/supertuxkart. The server only reads XML metadata and
# AngelScript track logic — everything graphical/audible is dead weight.
RUN cd /usr/local/share/supertuxkart/data && \
    find . -type f \( \
        -name '*.spm'  -o -name '*.b3d'  -o -name '*.obj' -o -name '*.mtl' -o \
        -name '*.png'  -o -name '*.jpg'  -o -name '*.jpeg' -o -name '*.dds' -o \
        -name '*.ogg'  -o -name '*.wav'  -o -name '*.music' -o \
        -name '*.frag' -o -name '*.vert' -o -name '*.glsl' -o \
        -name '*.comp' -o -name '*.vsh'  -o -name '*.fsh' -o \
        -name '*.challenge' -o -name '*.replay' \
    \) -delete && \
    find . -type d -empty -delete && \
    rm -rf /usr/local/share/icons \
           /usr/local/share/applications \
           /usr/local/share/metainfo

# -----------
# Final stage
# -----------

FROM ubuntu:24.04
WORKDIR /stk

# Runtime libraries only (not -dev packages)
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libcurl4 \
        libssl3 \
        libenet7 \
        libsqlite3-0 \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy artifacts from build stage
COPY --from=build /usr/local/bin/supertuxkart /usr/local/bin/
COPY --from=build /usr/local/share/supertuxkart /usr/local/share/supertuxkart
COPY docker-entrypoint.sh docker-entrypoint.sh

# STK network ports (UDP)
EXPOSE 2757/udp
EXPOSE 2759/udp

ENTRYPOINT ["/stk/docker-entrypoint.sh"]

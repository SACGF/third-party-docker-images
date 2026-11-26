ARG HTSLIB_VERSION=1.25

FROM rust:1.88.0-bookworm AS build

ARG HTSLIB_VERSION
ARG REPO_TAG=47448bdd302d12f6553cc9db72b0348f67a89b91

RUN apt-get update && apt-get -y install --no-install-recommends \
    libbz2-dev \
    libcurl4-openssl-dev \
    liblzma-dev \
    libssl-dev \
    zlib1g-dev \
    && \
    rm -rf /var/lib/apt/lists/*

# htslib and samtools from the same release, installed to /usr/local
WORKDIR /tmp/src
RUN wget -q https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjf htslib-${HTSLIB_VERSION}.tar.bz2 && \
    cd htslib-${HTSLIB_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install
RUN wget -q https://github.com/samtools/samtools/releases/download/${HTSLIB_VERSION}/samtools-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjf samtools-${HTSLIB_VERSION}.tar.bz2 && \
    cd samtools-${HTSLIB_VERSION} && \
    ./configure --prefix=/usr/local --with-htslib=system --without-curses && \
    make -j"$(nproc)" && \
    make install

# baldur links libhts dynamically
RUN git clone https://github.com/heathsc/baldur.git /tmp/src/baldur && \
    cd /tmp/src/baldur && \
    git checkout ${REPO_TAG} && \
    RUSTFLAGS="-L /usr/local/lib" cargo build --release --locked && \
    install -D -m 755 target/release/baldur /usr/local/bin/baldur && \
    install -D -m 644 share/blacklist.txt /usr/local/share/baldur/blacklist.txt


FROM debian:bookworm-slim

RUN apt-get update && apt-get -y install --no-install-recommends \
    ca-certificates \
    libbz2-1.0 \
    libcurl4 \
    libdeflate0 \
    liblzma5 \
    libssl3 \
    procps \
    zlib1g \
    && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/ /usr/local/bin/
COPY --from=build /usr/local/lib/libhts.so* /usr/local/lib/
COPY --from=build /usr/local/share/baldur/ /usr/local/share/baldur/

RUN ldconfig && \
    baldur --version && \
    bgzip --version && \
    samtools --version

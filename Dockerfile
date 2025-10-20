# syntax=docker/dockerfile:1.5.2

# Build nsjail
FROM debian:trixie-slim@sha256:1caf1c703c8f7e15dcf2e7769b35000c764e6f50e4d7401c355fb0248f3ddfdb AS nsjail
WORKDIR /app

# Install build dependencies only in builder image, based on upstream Dockerfile
RUN apt-get -y update && apt-get install -y \
    libc6 \
    libstdc++6 \
    libprotobuf32 \
    libnl-route-3-200 \
    autoconf \
    bison \
    flex \
    gcc \
    g++ \
    git \
    libprotobuf-dev \
    libnl-route-3-dev \
    libtool \
    make \
    pkg-config \
    protobuf-compiler

RUN git clone --depth 1 --branch 3.4 https://github.com/google/nsjail.git /app

RUN cd /app && make clean && make && ls && ls -la


# Build redpwn jailrun
FROM golang:1.25.3-trixie@sha256:ec34da704131e660a918be22604901ede84cf969070c97128ab0f0ed9c7939dd AS run
WORKDIR /app

RUN apt-get update && apt-get install -y \
    libseccomp-dev libgmp-dev

COPY go.mod go.sum ./
RUN go mod download
COPY cmd cmd
COPY internal internal
RUN go build -v -ldflags '-w -s' ./cmd/jailrun


# Jail environment preparation
FROM busybox:1.37.0-glibc AS image
RUN adduser -HDu 1000 jail && \
  mkdir -p /srv /jail/cgroup/cpu /jail/cgroup/mem /jail/cgroup/pids /jail/cgroup/unified
COPY --link --from=nsjail /usr/lib/*-linux-gnu/libprotobuf.so.32 /usr/lib/*-linux-gnu/libnl-route-3.so.200 \
  /lib/*-linux-gnu/libnl-3.so.200 /lib/*-linux-gnu/libz.so.1 /usr/lib/*-linux-gnu/libstdc++.so.6 \
  /lib/*-linux-gnu/libgcc_s.so.1 /lib/
COPY --link --from=run /usr/lib/*-linux-gnu/libseccomp.so.2 /usr/lib/*-linux-gnu/libgmp.so.10 /lib/
COPY --link --from=nsjail /app/nsjail /jail/nsjail
COPY --link --from=run /app/jailrun /jail/run


# Build jail container
FROM scratch
COPY --from=image / /
CMD ["/jail/run"]

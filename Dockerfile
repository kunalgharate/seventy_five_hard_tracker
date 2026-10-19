# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.38.3
ARG DART_VERSION=3.10.1
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH} \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true

# These packages are the Linux prerequisites for downloading and running the
# Flutter SDK and for producing a web build.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libglu1-mesa \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir --parents /opt \
    && curl --fail --location --show-error --silent \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        | tar --extract --xz --directory /opt \
    && flutter --version | grep --fixed-strings --quiet "Flutter ${FLUTTER_VERSION}" \
    && dart --version 2>&1 | grep --fixed-strings --quiet "${DART_VERSION}" \
    && flutter config --no-analytics

WORKDIR /app

# Resolve the locked package graph before copying the rest of the source so
# Docker can reuse this layer when only application files change.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM python:3.13-slim-bookworm AS preview

WORKDIR /srv
COPY --from=build /app/build/web ./

EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080", "--directory", "/srv"]

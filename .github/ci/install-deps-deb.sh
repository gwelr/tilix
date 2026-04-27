#!/bin/sh
#
# Install Tilix build dependencies
#
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

# update caches
apt-get update -qq

# install build essentials
apt-get install -yq \
        eatmydata \
        build-essential

# install build dependencies. Note: ldc and its runtime libxml2
# dependency are handled by install-ldc-tarball.sh — ldc is currently
# missing from Debian Testing during a transition, and libxml2 went
# through a SONAME bump in the same suite (libxml2.so.2 → .so.16)
# so the package name varies. curl/xz-utils/ca-certificates are the
# tools install-ldc-tarball.sh needs.
eatmydata apt-get install -yq \
        meson \
        ninja-build \
        appstream \
        ca-certificates \
        curl \
        desktop-file-utils \
        git \
        libatk1.0-dev \
        libcairo2-dev \
        libglib2.0-dev \
        libgtk-3-dev \
        libpango1.0-dev \
        librsvg2-dev \
        libsecret-1-dev \
        libgtksourceview-3.0-dev \
        libpeas-dev \
        libvte-2.91-dev \
        po4a \
        xvfb \
        xz-utils

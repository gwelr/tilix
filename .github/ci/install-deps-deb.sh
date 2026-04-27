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

# install build dependencies. Note: ldc is installed from the upstream
# tarball by install-ldc-tarball.sh — it is currently missing from
# Debian Testing during a transition. curl/xz-utils/ca-certificates are
# the tools that script needs. libxml2 is a runtime dependency of the
# upstream LDC binary itself (the prebuilt tarball dynamically links to
# libxml2.so.2; missing from Debian Testing's base image otherwise).
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
        libxml2 \
        po4a \
        xvfb \
        xz-utils

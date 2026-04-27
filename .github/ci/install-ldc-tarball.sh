#!/bin/sh
#
# Install LDC (LLVM D Compiler) from the upstream binary tarball.
#
# Why not apt: ldc is currently missing from Debian Testing during a
# transition (was in stable/trixie and unstable/sid, but not testing/forky).
# Same class of issue as the GtkD-from-source fix in #49. The upstream
# tarball install is version-pinned and distro-independent, so a future
# apt-archive disruption does not break the CI.
#
# Pinned to 1.40.0 to match what Debian Stable (trixie) ships, so the
# Stable and Testing CI builds are not silently testing different
# compiler versions.
set -e
set -x

LDC_VERSION="1.40.0"
LDC_PLATFORM="linux-x86_64"
LDC_TARBALL="ldc2-${LDC_VERSION}-${LDC_PLATFORM}.tar.xz"
LDC_URL="https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/${LDC_TARBALL}"
LDC_PREFIX="/opt/ldc2"

mkdir -p "${LDC_PREFIX}"
curl -fsSL "${LDC_URL}" | tar -xJ --strip-components=1 -C "${LDC_PREFIX}"

# Symlink LDC tooling onto PATH. dub is bundled with the official tarball.
for tool in ldc2 ldmd2 ldc-build-runtime ldc-profdata ldc-profgen dub; do
    if [ -x "${LDC_PREFIX}/bin/${tool}" ]; then
        ln -sf "${LDC_PREFIX}/bin/${tool}" "/usr/local/bin/${tool}"
    fi
done

# Make LDC's runtime libraries discoverable by the dynamic linker.
echo "${LDC_PREFIX}/lib" > /etc/ld.so.conf.d/ldc.conf
ldconfig

# Smoke-test: if ldc2 fails to launch, dump all unresolved shared
# libraries before exiting so the next CI iteration can fix them all
# at once instead of discovering them one-by-one.
if ! ldc2 --version; then
    echo "===== ldc2 failed to launch — dumping ldd output ====="
    ldd "${LDC_PREFIX}/bin/ldc2" || true
    exit 1
fi

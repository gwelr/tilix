#!/bin/bash
# Debug launcher for ttyx_
# Runs ttyx_ under GDB with GTK debug flags
#
# Usage:
#   ./debug-ttyx.sh              # normal debug run
#   ./debug-ttyx.sh --rebuild    # rebuild first, then debug
#   ./debug-ttyx.sh --core       # analyze most recent core dump

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/builddir"
BINARY="$BUILD_DIR/ttyx"
SCHEMAS_DIR="$SCRIPT_DIR/data/gsettings"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "${1:-}" in
    --rebuild)
        echo -e "${YELLOW}Rebuilding with debug symbols...${NC}"
        ninja -C "$BUILD_DIR"
        echo -e "${GREEN}Build complete.${NC}"
        shift
        ;;
    --core)
        echo -e "${YELLOW}Opening most recent ttyx_ core dump...${NC}"
        coredumpctl debug ttyx
        exit $?
        ;;
esac

if [ ! -f "$BINARY" ]; then
    echo -e "${RED}Binary not found at $BINARY${NC}"
    echo "Run: meson setup builddir && ninja -C builddir"
    exit 1
fi

# Kill any running ttyx_ instance (GTK single-instance via D-Bus)
if pgrep -x ttyx > /dev/null 2>&1; then
    echo -e "${YELLOW}Killing existing ttyx_ instance (GTK single-instance mode)...${NC}"
    killall ttyx 2>/dev/null || true
    sleep 1
fi

# Compile schemas so our dev settings work
if [ -d "$SCHEMAS_DIR" ]; then
    echo -e "${YELLOW}Compiling GSettings schemas...${NC}"
    glib-compile-schemas "$SCHEMAS_DIR"
    export GSETTINGS_SCHEMA_DIR="$SCHEMAS_DIR"
fi

# Make the build directory's gresource findable via XDG_DATA_DIRS.
# The app searches for ttyx/resources/ttyx.gresource under each XDG data dir.
# We create a symlink so that $BUILD_DIR/data/ttyx/resources/ttyx.gresource
# points to the compiled gresource at $BUILD_DIR/data/ttyx.gresource.
RESOURCE_LINK_DIR="$BUILD_DIR/data/ttyx/resources"
mkdir -p "$RESOURCE_LINK_DIR"
ln -sf "$BUILD_DIR/data/ttyx.gresource" "$RESOURCE_LINK_DIR/ttyx.gresource"
export XDG_DATA_DIRS="$BUILD_DIR/data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Enable core dumps for this session
ulimit -c unlimited 2>/dev/null || true

echo -e "${GREEN}Launching ttyx_ under GDB...${NC}"
echo ""
echo -e "  ${YELLOW}Useful GDB commands:${NC}"
echo "    run              - start ttyx_"
echo "    bt               - backtrace after crash"
echo "    bt full          - backtrace with local variables"
echo "    info threads     - list all threads"
echo "    thread N         - switch to thread N"
echo "    continue         - resume after a breakpoint"
echo "    quit             - exit GDB"
echo ""

# G_DEBUG options:
#   fatal-criticals — turn GTK CRITICAL warnings into crashes (catches bugs early)
#   fatal-warnings  — even stricter, all GLib warnings become fatal
#
# Note: fatal-criticals catches real bugs but also harmless VTE/GTK
# internal warnings we can't fix (e.g., VTE scrolling on unmapped tabs).
# Disabled by default. Uncomment to enable for focused debugging:
# export G_DEBUG=fatal-criticals

# --new-process disables GApplication session-bus registration so we get a
# fresh instance under gdb. Tradeoff: `ttyx -a <action>` invocations from
# a shell cannot discover this instance and will print "No ttyx_ instance
# registered on the session bus...". Launch ttyx_ without this wrapper if
# you need to test CLI actions. See CONTRIBUTING.md > Using debug-ttyx.sh.
exec gdb \
    -ex "set print pretty on" \
    -ex "set pagination off" \
    -ex "set confirm off" \
    -ex "handle SIG32 nostop noprint pass" \
    -ex "handle SIG33 nostop noprint pass" \
    -ex "handle SIG34 nostop noprint pass" \
    -ex "handle SIG35 nostop noprint pass" \
    -ex "handle SIGPIPE nostop noprint pass" \
    --args "$BINARY" --new-process "$@"

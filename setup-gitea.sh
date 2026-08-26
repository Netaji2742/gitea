#!/usr/bin/env bash
#
# setup-gitea.sh
#
# Automates building and running Gitea locally, without Docker.
# Usage: ./setup-gitea.sh   (run from inside the cloned gitea repo)
#
# What it does:
#   1. Verifies it's being run from the correct Gitea project directory
#   2. Checks required tools are installed (go, node, pnpm, make, git)
#   3. Checks and displays each tool's version
#   4. Builds Gitea from source (backend + frontend, with bindata)
#   5. Verifies the resulting binary was created
#   6. Checks whether port 3000 is already in use
#   7. Starts the Gitea web server
#   8. Displays the local URL to open

set -uo pipefail   # (not -e: we want to handle failures ourselves with clear messages)

# ---------- colours for readable status output ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------- resolve paths relative to the script itself, never hard-coded ----------
# This makes the script work regardless of which user or machine runs it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BINARY_NAME="gitea"
PORT=3000
BUILD_TAGS="bindata"

# =========================================================
# Step 1: Verify we're in the correct Gitea project directory
# =========================================================
info "Checking project directory..."

if [[ ! -f "$PROJECT_DIR/go.mod" ]] || [[ ! -f "$PROJECT_DIR/Makefile" ]]; then
    error "This does not look like the Gitea project root (missing go.mod or Makefile)."
    error "Place this script in the root of your cloned gitea repository and re-run it."
    exit 1
fi

if ! grep -q "^module .*gitea" "$PROJECT_DIR/go.mod" 2>/dev/null; then
    error "go.mod found, but it doesn't look like Gitea's module. Are you in the right repo?"
    exit 1
fi

success "Running from a valid Gitea project directory: $PROJECT_DIR"

cd "$PROJECT_DIR" || { error "Could not cd into $PROJECT_DIR"; exit 1; }

# =========================================================
# Step 2 & 3: Check required tools are installed + show versions
# =========================================================
info "Checking required tools..."

MISSING_TOOLS=()

check_tool() {
    local tool="$1"
    local version_cmd="$2"
    if command -v "$tool" >/dev/null 2>&1; then
        local version
        version="$(eval "$version_cmd" 2>/dev/null | head -n1)"
        success "$tool found — $version"
    else
        error "$tool is not installed or not on PATH"
        MISSING_TOOLS+=("$tool")
    fi
}

check_tool "go"   "go version"
check_tool "node" "node -v"
check_tool "pnpm" "pnpm -v"
check_tool "make" "make -v"
check_tool "git"  "git --version"

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    error "Missing required tools: ${MISSING_TOOLS[*]}"
    error "Install them before running this script again. See docs/build-source.md for requirements."
    exit 1
fi

# ---- Minimum version sanity checks (based on this project's go.mod / package.json) ----
GO_VERSION_RAW="$(go version | awk '{print $3}' | sed 's/go//')"
GO_MAJOR="$(echo "$GO_VERSION_RAW" | cut -d. -f1)"
GO_MINOR="$(echo "$GO_VERSION_RAW" | cut -d. -f2)"
if [[ "$GO_MAJOR" -lt 1 ]] || { [[ "$GO_MAJOR" -eq 1 ]] && [[ "$GO_MINOR" -lt 23 ]]; }; then
    warn "Go version $GO_VERSION_RAW detected — this project expects a recent Go toolchain. Build may fail."
fi

NODE_VERSION_RAW="$(node -v | sed 's/v//')"
NODE_MAJOR="$(echo "$NODE_VERSION_RAW" | cut -d. -f1)"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
    warn "Node version $NODE_VERSION_RAW detected — this project expects Node >= 22.18.0. Build may fail."
fi

success "All required tools are present."

# =========================================================
# Step 4: Build Gitea from source
# =========================================================
info "Building Gitea (this can take several minutes on first run)..."

if TAGS="$BUILD_TAGS" make build; then
    success "Build completed."
else
    error "Build failed. Scroll up for the compiler/pnpm error output."
    exit 1
fi

# =========================================================
# Step 5: Verify the binary was created
# =========================================================
info "Verifying the Gitea binary..."

if [[ -f "$PROJECT_DIR/$BINARY_NAME" ]] && [[ -x "$PROJECT_DIR/$BINARY_NAME" ]]; then
    success "Binary found at $PROJECT_DIR/$BINARY_NAME"
else
    error "Expected binary '$BINARY_NAME' was not found or is not executable after build."
    exit 1
fi

# =========================================================
# Step 6: Check whether port 3000 is already in use
# =========================================================
info "Checking whether port $PORT is already in use..."

PORT_IN_USE=false
if command -v lsof >/dev/null 2>&1; then
    if lsof -i ":$PORT" >/dev/null 2>&1; then
        PORT_IN_USE=true
    fi
elif command -v ss >/dev/null 2>&1; then
    if ss -tuln | grep -q ":$PORT[[:space:]]"; then
        PORT_IN_USE=true
    fi
else
    warn "Neither 'lsof' nor 'ss' found — skipping port check."
fi

if [[ "$PORT_IN_USE" == true ]]; then
    error "Port $PORT is already in use. Stop whatever is using it, or edit PORT in this script to use a different port."
    exit 1
fi

success "Port $PORT is free."

# =========================================================
# Step 7 & 8: Start the Gitea web server and display the URL
# =========================================================
info "Starting Gitea web server..."
success "Once started, open: http://localhost:$PORT"
info "Press Ctrl+C to stop the server."
echo ""

exec "$PROJECT_DIR/$BINARY_NAME" web
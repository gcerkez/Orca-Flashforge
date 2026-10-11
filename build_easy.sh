#!/usr/bin/env bash
# ==============================================================================
# build_easy.sh - Foolproof build script for Orca-Flashforge (Flash Studio)
# ==============================================================================
# Usage:
#   ./build_easy.sh [OPTIONS]
#
# Options:
#   -N, --flashnetwork <FILE>  Path to libFlashNetwork.so (auto-detected if omitted)
#   -c, --clean                Clean build directory before compiling
#   --clean-deps               Force rebuilding dependencies in ./deps
#   -j, --jobs <N>             Limit parallel build to N cores
#   --no-appimage              Compile binary only, skip AppImage packaging
#   -h, --help                 Show this help message
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
BOLD="\033[1m"
NC="\033[0m"

function log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

function usage() {
    echo -e "${BOLD}Orca-Flashforge Easy Build Script${NC}

${BOLD}Usage:${NC}
  ./build_easy.sh [OPTIONS]

${BOLD}Options:${NC}
  -N, --flashnetwork <FILE>   Path to libFlashNetwork.so (auto-discovered if omitted)
  -c, --clean                 Clean build directory before building
  --clean-deps                Clean and rebuild ./deps dependencies
  -j, --jobs <N>              Limit parallel compilation to N cores
  --no-appimage               Compile only, skip AppImage creation
  -h, --help                  Show this help message

${BOLD}Examples:${NC}
  ./build_easy.sh                                   # Standard build (auto-detects FlashNetwork)
  ./build_easy.sh -N /path/to/libFlashNetwork.so   # Specify explicit FlashNetwork library
  ./build_easy.sh --clean                           # Incremental clean rebuild"
}

FLASHNETWORK_LIB="${FLASHNETWORK_LIB:-}"
CLEAN_BUILD=0
CLEAN_DEPS=0
BUILD_APPIMAGE=1
JOBS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -N|--flashnetwork)
            FLASHNETWORK_LIB="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD=1
            shift
            ;;
        --clean-deps)
            CLEAN_DEPS=1
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --no-appimage)
            BUILD_APPIMAGE=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BOLD}======================================================${NC}"
echo -e "${BOLD}     Orca-Flashforge (Flash Studio) Easy Builder      ${NC}"
echo -e "${BOLD}======================================================${NC}"

# Check for essential tools
MISSING_TOOLS=()
for tool in cmake clang lld; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    log_error "Missing required build tools: ${MISSING_TOOLS[*]}"
    log_info "Inside Ubuntu 24.04 container, install them with:"
    log_info "  sudo apt update && sudo apt install -y build-essential cmake clang lld libgtk-3-dev libwebkit2gtk-4.1-dev"
    exit 1
fi

# Locate FlashNetwork library
if [[ -z "${FLASHNETWORK_LIB}" ]]; then
    CANDIDATES=(
        "${SCRIPT_DIR}/libFlashNetwork.so"
        "${SCRIPT_DIR}/../libFlashNetwork.so"
        "${SCRIPT_DIR}/build/package/bin/libFlashNetwork.so"
        "${SCRIPT_DIR}/resources/libFlashNetwork.so"
        "/home/gcerkez/.gemini/antigravity/scratch/orca-flashforge/libFlashNetwork.so"
    )
    for cand in "${CANDIDATES[@]}"; do
        if [[ -f "${cand}" ]]; then
            FLASHNETWORK_LIB="${cand}"
            break
        fi
    done
fi

if [[ -n "${FLASHNETWORK_LIB}" && -f "${FLASHNETWORK_LIB}" ]]; then
    FLASHNETWORK_LIB="$(readlink -f "${FLASHNETWORK_LIB}")"
    log_info "FlashNetwork library found: ${FLASHNETWORK_LIB}"
else
    log_warn "No libFlashNetwork.so found."
    log_warn "Network printing features will be limited unless -N /path/to/libFlashNetwork.so is provided."
    FLASHNETWORK_LIB=""
fi

# Determine if dependencies in ./deps need to be built
BUILD_DEPS_FLAG=""
if [[ ${CLEAN_DEPS} -eq 1 ]]; then
    log_info "Cleaning ./deps build directory..."
    rm -rf deps/build
    BUILD_DEPS_FLAG="-d"
elif [[ ! -d "deps/build/destdir" && ! -f "deps/build/CMakeCache.txt" ]]; then
    log_info "Dependencies not found in ./deps/build, will build dependencies first..."
    BUILD_DEPS_FLAG="-d"
else
    log_info "Existing dependencies detected in ./deps/build (skipping rebuild to save time)."
fi

# Handle clean build
if [[ ${CLEAN_BUILD} -eq 1 ]]; then
    log_info "Cleaning ./build directory..."
    rm -rf build
fi

# Prepare build flags for build_linux.sh:
# -s: build slicer
# -r: skip RAM and disk checks
# -l: use Clang compiler
# -L: use ld.lld linker
BUILD_FLAGS=("-s" "-r" "-l" "-L")

if [[ -n "${BUILD_DEPS_FLAG}" ]]; then
    BUILD_FLAGS+=("${BUILD_DEPS_FLAG}")
fi

if [[ ${BUILD_APPIMAGE} -eq 1 ]]; then
    BUILD_FLAGS+=("-i")
fi

if [[ -n "${JOBS}" ]]; then
    BUILD_FLAGS+=("-j" "${JOBS}")
fi

if [[ -n "${FLASHNETWORK_LIB}" ]]; then
    BUILD_FLAGS+=("-N" "${FLASHNETWORK_LIB}")
fi

log_info "Executing: ./build_linux.sh ${BUILD_FLAGS[*]}"
./build_linux.sh "${BUILD_FLAGS[@]}"

if [[ ${BUILD_APPIMAGE} -eq 1 ]]; then
    APPIMAGE_FILE=$(find "${SCRIPT_DIR}/build" -maxdepth 1 -name "*.AppImage" ! -name "*appimagetool*" | head -n 1)
    if [[ -n "${APPIMAGE_FILE}" && -f "${APPIMAGE_FILE}" ]]; then
        echo ""
        log_success "AppImage build completed successfully!"
        echo -e "  ${BOLD}Location:${NC} ${APPIMAGE_FILE}"
        echo -e "  ${BOLD}Size:${NC}     $(du -h "${APPIMAGE_FILE}" | cut -f1)"
        echo -e "  ${BOLD}SHA256:${NC}   $(sha256sum "${APPIMAGE_FILE}" | cut -d' ' -f1)"
        echo ""
        log_info "To run:"
        echo -e "  chmod +x \"${APPIMAGE_FILE}\""
        echo -e "  \"${APPIMAGE_FILE}\""
    else
        log_warn "Build completed, but AppImage file not located in build/."
    fi
else
    log_success "Binary build completed successfully in build/package/bin/!"
fi

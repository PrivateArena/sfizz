#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# defaults: mirror CMake ON/OFF defaults
RENDER=ON
TESTS=OFF
BENCHMARKS=OFF
JACK=OFF
DEMOS=OFF
DEVTOOLS=OFF
FAST_MATH=AUTO

usage() {
    cat <<EOF
Usage: $0 {plain|optimized|rebuild|clean} [flags]

Subcommands:
  plain         standard release build          -> build_plain/
  optimized     perf build with -march=native   -> build_optimized/
  rebuild       reconfigure + build optimized
  clean         remove build_plain/ and build_optimized/

Flags (apply to plain/optimized):
  --libs-only             Disable all optional binaries (render, tests, etc.)
  --[no-]render           Enable/disable sfizz_render          (default: on)
  --[no-]tests            Enable/disable test binary           (default: off)
  --[no-]benchmarks       Enable/disable benchmarks            (default: off)
  --[no-]jack             Enable/disable JACK client           (default: off)
  --[no-]demos            Enable/disable demo binaries         (default: off)
  --[no-]devtools         Enable/disable developer tools       (default: off)
  --[no-]fast-math        Enable/disable -ffast-math           (default: auto)
                          Auto: OFF for plain, ON for optimized
EOF
    exit 1
}

parse_flags() {
    for arg in "$@"; do
        case "$arg" in
            --libs-only)
                RENDER=OFF; TESTS=OFF; BENCHMARKS=OFF
                JACK=OFF; DEMOS=OFF; DEVTOOLS=OFF
                ;;
            --render)    RENDER=ON ;;
            --no-render) RENDER=OFF ;;
            --tests)     TESTS=ON ;;
            --no-tests)  TESTS=OFF ;;
            --benchmarks)     BENCHMARKS=ON ;;
            --no-benchmarks)  BENCHMARKS=OFF ;;
            --jack)      JACK=ON ;;
            --no-jack)   JACK=OFF ;;
            --demos)     DEMOS=ON ;;
            --no-demos)  DEMOS=OFF ;;
            --devtools)  DEVTOOLS=ON ;;
            --no-devtools) DEVTOOLS=OFF ;;
            --fast-math)    FAST_MATH=ON ;;
            --no-fast-math) FAST_MATH=OFF ;;
            --help|-h)   usage ;;
            *)
                echo "Unknown flag: $arg"
                usage
                ;;
        esac
    done
}

cmake_flags() {
    echo "-D CMAKE_BUILD_TYPE=Release"
    echo "-D SFIZZ_RENDER=$1"
    echo "-D SFIZZ_TESTS=$2"
    echo "-D SFIZZ_BENCHMARKS=$3"
    echo "-D SFIZZ_JACK=$4"
    echo "-D SFIZZ_DEMOS=$5"
    echo "-D SFIZZ_DEVTOOLS=$6"
    echo "-D SFIZZ_FAST_MATH=$7"
}

build_plain() {
    local flags
    flags=$(cmake_flags "$RENDER" "$TESTS" "$BENCHMARKS" "$JACK" "$DEMOS" "$DEVTOOLS" "$FAST_MATH")
    cmake -S "$ROOT" -B "$ROOT/build_plain" $flags
    cmake --build "$ROOT/build_plain" --parallel
}

build_optimized() {
    local fast="$FAST_MATH"
    [[ "$fast" == AUTO ]] && fast=ON
    local flags
    flags=$(cmake_flags "$RENDER" "$TESTS" "$BENCHMARKS" "$JACK" "$DEMOS" "$DEVTOOLS" "$fast")
    cmake -S "$ROOT" -B "$ROOT/build_optimized" \
        $flags \
        -D CMAKE_C_FLAGS="-O3 -march=native -flto" \
        -D CMAKE_CXX_FLAGS="-O3 -march=native -flto"
    cmake --build "$ROOT/build_optimized" --parallel
}

cmd="${1:-help}"
shift 2>/dev/null || true
parse_flags "$@"

case "$cmd" in
    plain)
        build_plain
        ;;
    optimized|perf|zen)
        build_optimized
        ;;
    rebuild)
        rm -f "$ROOT/build_optimized/CMakeCache.txt"
        build_optimized
        ;;
    clean)
        rm -rf "$ROOT/build_plain" "$ROOT/build_optimized"
        echo "Removed build_plain/ and build_optimized/"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $cmd"
        usage
        ;;
esac

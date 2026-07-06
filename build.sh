#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

build_plain() {
    cmake -S "$ROOT" -B "$ROOT/build_plain" \
        -D CMAKE_BUILD_TYPE=Release \
        -D SFIZZ_JACK=OFF \
        -D SFIZZ_TESTS=OFF \
        -D SFIZZ_BENCHMARKS=OFF
    cmake --build "$ROOT/build_plain" --parallel
}

build_optimized() {
    cmake -S "$ROOT" -B "$ROOT/build_optimized" \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_C_FLAGS="-O3 -march=native -flto -ffast-math" \
        -D CMAKE_CXX_FLAGS="-O3 -march=native -flto -ffast-math" \
        -D SFIZZ_JACK=OFF \
        -D SFIZZ_TESTS=OFF \
        -D SFIZZ_BENCHMARKS=OFF \
        -D SFIZZ_FAST_MATH=ON
    cmake --build "$ROOT/build_optimized" --parallel
}

rebuild_optimized() {
    rm -f "$ROOT/build_optimized/CMakeCache.txt"
    build_optimized
}

case "${1:-help}" in
    plain)
        build_plain
        ;;
    optimized|perf|zen)
        build_optimized
        ;;
    rebuild)
        rebuild_optimized
        ;;
    clean)
        rm -rf "$ROOT/build_plain" "$ROOT/build_optimized"
        echo "Removed build_plain/ and build_optimized/"
        ;;
    *)
        echo "Usage: $0 {plain|optimized|rebuild|clean}"
        echo "  plain      - standard release build     -> build_plain/"
        echo "  optimized  - perf build with -march=native -flto  -> build_optimized/"
        echo "  rebuild    - reconfigure + build optimized"
        echo "  clean      - remove both build dirs"
        exit 1
        ;;
esac

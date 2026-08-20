#!/bin/bash
# Source this file to enable cmake-hgcc in your shell environment.
#
# Usage:
#   source /path/to/cmake-hgcc/envsetup.sh
#
# After sourcing, cmake will automatically find the HG language modules:
#   cmake -B build   (CMAKE_MODULE_PATH is set)
#
# If cmake-hgcc has been installed via `cmake --install`, source the
# installed version instead, or set CMAKE_PREFIX_PATH to the install prefix.

_CMAKE_HGCC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# NOTE: CMake does not read the CMAKE_MODULE_PATH environment variable
# (undocumented, verified ignored by CMake 4.3); projects must append the
# module dir to CMAKE_MODULE_PATH themselves (gloo's cmake/Hggc.cmake does).
# Kept for tooling that reads the env var directly. Uses ';' (CMake list
# separator) in case an older CMake version does honor it.
export CMAKE_MODULE_PATH="${_CMAKE_HGCC_DIR}/cmake/Modules${CMAKE_MODULE_PATH:+;${CMAKE_MODULE_PATH}}"
# CMake splits the CMAKE_PREFIX_PATH environment variable on ':' (PATH-like),
# NOT on ';'. Prepending with ';' corrupts the list when an existing value is
# ':'-separated (e.g. set by conda): the whole ';' chunk becomes one bogus
# path and cmake-hgcc is never searched. Use ':' to stay consistent.
export CMAKE_PREFIX_PATH="${_CMAKE_HGCC_DIR}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"

echo "cmake-hgcc: enabled (${_CMAKE_HGCC_DIR})"
echo "  CMAKE_MODULE_PATH includes: ${_CMAKE_HGCC_DIR}/cmake/Modules"

unset _CMAKE_HGCC_DIR

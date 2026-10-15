cmake_minimum_required(VERSION 3.20)

# Covers hgcc_fatbin_to_header(): a fatbin produced by hgcc_add_fatbin() must be
# convertible to an embeddable C header via hgbin2c.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules -S . -B build
#   cmake --build build

project(hggc_fatbin_to_header LANGUAGES CXX HG)

include(HGGCUtilities)

# Kernel source shared with test/.
set(_shared_src "${CMAKE_CURRENT_SOURCE_DIR}/../../../../test")

hgcc_add_fatbin(embed_fatbin "${_shared_src}/test_fatbin_kernel.hg")

set(EMBED_HEADER "${CMAKE_CURRENT_BINARY_DIR}/embed_fatbin.h")
hgcc_fatbin_to_header("${embed_fatbin_OUTPUT}" "${EMBED_HEADER}")

# hgcc_fatbin_to_header() only declares a custom command — without a target
# depending on its output the header is never generated. Verifying that wiring is
# part of this case.
add_custom_target(embed_fatbin_header ALL DEPENDS "${EMBED_HEADER}")
add_dependencies(embed_fatbin_header embed_fatbin)

message(STATUS "fatbin: ${embed_fatbin_OUTPUT}")
message(STATUS "header: ${EMBED_HEADER}")

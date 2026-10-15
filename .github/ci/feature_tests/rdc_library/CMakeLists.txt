cmake_minimum_required(VERSION 3.20)

# Covers hgcc_add_rdc_library(): device code in a STATIC library must survive the
# device link phase when the library is consumed by an executable. test/ only
# covers RDC executables, so multi-target RDC linking has no coverage there.
#
# Sources are test/'s rdc_mixed sources, reused unchanged: only the way they are
# assembled into targets differs.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules -S . -B build
#   cmake --build build

project(hggc_rdc_library LANGUAGES CXX HG)

include(HGGCUtilities)

set(_shared_src "${CMAKE_CURRENT_SOURCE_DIR}/../../../../test")

hgcc_add_rdc_library(rdc_kernels STATIC
  "${_shared_src}/test_rdc_helper.hg"
  "${_shared_src}/test_rdc_kernel.hg")

# The consumer needs RDC too: hgcc performs the device link when it acts as the
# linker, and the device symbols live in the archive.
add_executable(test_rdc_lib_user "${_shared_src}/test_rdc_main.cpp")
hgcc_enable_rdc(test_rdc_lib_user)
target_link_libraries(test_rdc_lib_user PRIVATE rdc_kernels)

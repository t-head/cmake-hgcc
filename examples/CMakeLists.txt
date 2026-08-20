# Migration examples: hggc-samples converted to cmake-hgcc
#
# This file demonstrates how to migrate existing hggc-samples CMakeLists.txt
# from the manual add_custom_command pattern to native cmake-hgcc support.
#
# Usage:
#   cd examples && mkdir build && cd build
#   cmake -DCMAKE_MODULE_PATH=../../cmake/Modules \
#         -DHGGC_SAMPLES_DIR=/path/to/hggc-samples ..
#   make

cmake_minimum_required(VERSION 3.20)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake/Modules")

project(cmake_hgcc_migration_examples LANGUAGES CXX HG)

include(HGGCUtilities)
find_package(HGGCToolkit)

# --- Locate hggc-samples source tree ---
set(HGGC_SAMPLES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../hggc-samples"
  CACHE PATH "Path to hggc-samples source tree")

if(NOT EXISTS "${HGGC_SAMPLES_DIR}/Common/helper_hggc.h")
  message(FATAL_ERROR
    "Cannot find hggc-samples at: ${HGGC_SAMPLES_DIR}\n"
    "Set -DHGGC_SAMPLES_DIR=/path/to/hggc-samples")
endif()

set(COMMON_DIR "${HGGC_SAMPLES_DIR}/Common")
set(TEST_COMMON "${HGGC_SAMPLES_DIR}/conformance_tests/common")

message(STATUS "")
message(STATUS "=== Migration Examples ===")
message(STATUS "Using hggc-samples from: ${HGGC_SAMPLES_DIR}")
message(STATUS "")

# ============================================================
# Example 1: vectorAdd — single .hg file
# ============================================================
# BEFORE (19 lines):
#   project(vectorAdd_hgcc NONE)
#   set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/vectorAdd.hg)
#   set(OUT ${CMAKE_CURRENT_BINARY_DIR}/vectorAdd.out)
#   set(COMMON_DIR ...)
#   add_custom_command(OUTPUT ${OUT}
#       COMMAND hgcc -x hg ${SRC} -I ${COMMON_DIR} -o ${OUT}
#       DEPENDS ${SRC} ...)
#   add_custom_target(vectorAdd ALL DEPENDS ${OUT})
#
# AFTER (2 lines):
add_executable(vectorAdd
  ${HGGC_SAMPLES_DIR}/Samples/0_Introduction/vectorAdd/vectorAdd.hg)
target_include_directories(vectorAdd PRIVATE ${COMMON_DIR})

# ============================================================
# Example 2: mergeSort — mixed .hg + .cpp (5 source files)
# ============================================================
# BEFORE: same pattern, all 5 files passed to a single hgcc command
# AFTER:
set(_mergeSort_dir ${HGGC_SAMPLES_DIR}/Samples/0_Introduction/mergeSort)
add_executable(mergeSort
  ${_mergeSort_dir}/bitonic.hg
  ${_mergeSort_dir}/mergeSort.hg
  ${_mergeSort_dir}/main.cpp
  ${_mergeSort_dir}/mergeSort_host.cpp
  ${_mergeSort_dir}/mergeSort_validate.cpp)
target_include_directories(mergeSort PRIVATE ${COMMON_DIR})
target_link_libraries(mergeSort PRIVATE HGGC::toolkit)

# ============================================================
# Example 3: hggcOpenMP — linking with external library
# ============================================================
# BEFORE: hgcc ... -l gomp
# AFTER:
add_executable(hggcOpenMP
  ${HGGC_SAMPLES_DIR}/Samples/0_Introduction/hggcOpenMP/hggcOpenMP.hg)
target_include_directories(hggcOpenMP PRIVATE ${COMMON_DIR})
target_link_libraries(hggcOpenMP PRIVATE gomp)

# ============================================================
# Example 4: vectorAddDrv — fatbin + Driver API
# ============================================================
# BEFORE: two add_custom_command (fatbin + exe), add_custom_target
# AFTER:
# fatbin generation demo (Driver API sample has SDK API mismatch, skip the exe)
set(_vectorAddDrv_dir ${HGGC_SAMPLES_DIR}/Samples/0_Introduction/vectorAddDrv)
hgcc_add_fatbin(vectorAdd_kernel64
  ${_vectorAddDrv_dir}/vectorAdd_kernel.hg
  INCLUDE_DIRECTORIES ${COMMON_DIR})

# ============================================================
# Example 5: conformance_tests/hggc_math — batch (foreach)
# ============================================================
# BEFORE: foreach with add_custom_command + add_custom_target per test
# AFTER:
set(_math_dir ${HGGC_SAMPLES_DIR}/conformance_tests/hggc_math)
foreach(_test test_math_trig test_math_exp_log test_math_special
              test_math_integer test_math_rounding test_math_random_sweep
              test_math_extra test_math_identity)
  if(EXISTS "${_math_dir}/${_test}.hg")
    add_executable(${_test} ${_math_dir}/${_test}.hg)
    target_include_directories(${_test} PRIVATE ${COMMON_DIR} ${TEST_COMMON})
  endif()
endforeach()

message(STATUS "Migration examples configured successfully")
message(STATUS "")

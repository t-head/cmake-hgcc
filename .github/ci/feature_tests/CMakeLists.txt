cmake_minimum_required(VERSION 3.20)

# Feature tests for cmake-hgcc, run by .github/workflows/ci.yml next to test/.
#
# test/ covers the basic build paths (single .hg, mixed .hg + .cpp, fatbin, RDC
# executables, .cu sources, shared library). Each case below covers a documented
# feature that test/ does not exercise, as an isolated nested project built
# through `ctest --build-and-test`: some cases need configure-time cache
# variables that cannot coexist in one build tree, and a failure in one case
# must not drag the others down with it. The parent build never compiles them.
#
# Cases marked NEEDS_DEVICE produce binaries that carry device code and load the
# PPU runtime. They are always configured and built, but their binaries only run
# with -DHGGC_RUN_DEVICE_TESTS=ON: GitHub-hosted runners have no PPU device. CI
# runs them on a PPU with .github/ci/run_device_tests.sh, which lists them too.
#
# Usage:
#   cmake -S .github/ci/feature_tests -B build-features [-DHGGC_RUN_DEVICE_TESTS=ON]
#   ctest --test-dir build-features --output-on-failure

# The modules under test are the ones in this checkout.
get_filename_component(HGGC_MODULE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake/Modules" ABSOLUTE)
if(NOT EXISTS "${HGGC_MODULE_DIR}/CMakeDetermineHGCompiler.cmake")
  message(FATAL_ERROR "cmake-hgcc HG language modules not found in ${HGGC_MODULE_DIR}")
endif()
list(APPEND CMAKE_MODULE_PATH "${HGGC_MODULE_DIR}")

# Default to both PPU generations so one build serves PPU 1.0 (ppu_10) and
# PPU 1.5 (ppu_15) alike: the fatbin carries code for both archs and the runtime
# picks the matching one. Kept comma-separated on purpose: a semicolon CMake list
# would fall apart when forwarded to the nested projects as a single -D argument,
# while hgcc accepts the comma form natively. Override with
# -DCMAKE_HG_ARCHITECTURES=<arch[,arch...]> to narrow it down.
if(NOT DEFINED CMAKE_HG_ARCHITECTURES)
  set(CMAKE_HG_ARCHITECTURES "ppu_10,ppu_15")
endif()

project(cmake_hgcc_feature_tests LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)

option(HGGC_RUN_DEVICE_TESTS "Also run the binaries of the cases that need a PPU device" OFF)

enable_testing()

message(STATUS "")
message(STATUS "=== cmake-hgcc feature tests ===")
message(STATUS "HG modules:        ${HGGC_MODULE_DIR}")
message(STATUS "HG compiler:       ${CMAKE_HG_COMPILER}")
message(STATUS "HG version:        ${CMAKE_HG_COMPILER_VERSION}")
message(STATUS "HG architectures:  ${CMAKE_HG_ARCHITECTURES}")
message(STATUS "Toolkit root:      ${CMAKE_HG_TOOLKIT_ROOT}")
message(STATUS "Toolkit version:   ${HGGCToolkit_VERSION}")
message(STATUS "Run device tests:  ${HGGC_RUN_DEVICE_TESTS}")
message(STATUS "")

# hggc_add_feature_test(<name> [NEEDS_DEVICE]
#                       [BUILD_OPTIONS <cmake-arg>...]
#                       [TEST_COMMAND <command> [<arg>...]])
#
# Configures and builds the nested project in <name>/, then runs TEST_COMMAND.
# Without TEST_COMMAND, or for a NEEDS_DEVICE case while HGGC_RUN_DEVICE_TESTS
# is OFF, configure + build is the whole check.
function(hggc_add_feature_test _name)
  cmake_parse_arguments(_ft "NEEDS_DEVICE" "" "BUILD_OPTIONS;TEST_COMMAND" ${ARGN})

  set(_ft_src "${CMAKE_CURRENT_SOURCE_DIR}/${_name}")
  set(_ft_bin "${CMAKE_CURRENT_BINARY_DIR}/${_name}")

  set(_cmd "${CMAKE_CTEST_COMMAND}"
    --build-and-test "${_ft_src}" "${_ft_bin}"
    --build-generator "${CMAKE_GENERATOR}")
  if(CMAKE_MAKE_PROGRAM)
    list(APPEND _cmd --build-makeprogram "${CMAKE_MAKE_PROGRAM}")
  endif()

  # --build-options consumes every following argument up to --test-command, so
  # these two have to stay in this order. Forward the device architectures too:
  # the nested project is a fresh configure and would otherwise fall back to
  # the compiler's default arch.
  set(_ft_arch_option "")
  if(CMAKE_HG_ARCHITECTURES)
    set(_ft_arch_option "-DCMAKE_HG_ARCHITECTURES=${CMAKE_HG_ARCHITECTURES}")
  endif()
  list(APPEND _cmd --build-options
    "-DCMAKE_MODULE_PATH=${HGGC_MODULE_DIR}"
    ${_ft_arch_option}
    ${_ft_BUILD_OPTIONS})

  if(_ft_TEST_COMMAND AND (HGGC_RUN_DEVICE_TESTS OR NOT _ft_NEEDS_DEVICE))
    list(APPEND _cmd --test-command ${_ft_TEST_COMMAND})
  else()
    # Configure + build is the whole check; give ctest a no-op to run.
    list(APPEND _cmd --test-command "${CMAKE_COMMAND}" -E true)
  endif()

  add_test(NAME ${_name} COMMAND ${_cmd})

  if(_ft_NEEDS_DEVICE)
    set_tests_properties(${_name} PROPERTIES LABELS device)
    if(NOT HGGC_RUN_DEVICE_TESTS)
      message(STATUS "${_name}: configure + build only (HGGC_RUN_DEVICE_TESTS=OFF)")
    endif()
  endif()
endfunction()

set(_ft_bin_root "${CMAKE_CURRENT_BINARY_DIR}")

# set_standard and compiler_launcher assert at compile time, so building them is
# already the full check. rdc_library and runtime_library_none launch kernels.

# --- hgcc_set_standard() overrides CMAKE_HG_STANDARD per target ---
hggc_add_feature_test(set_standard NEEDS_DEVICE
  TEST_COMMAND "${_ft_bin_root}/set_standard/probe_cxx14")

# --- hgcc_fatbin_to_header() produces an embeddable header ---
hggc_add_feature_test(fatbin_to_header
  TEST_COMMAND "${CMAKE_COMMAND}"
    "-DFILE=${_ft_bin_root}/fatbin_to_header/embed_fatbin.h"
    -DMIN_SIZE=64
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_file_nonempty.cmake")

# hgcc_fatbin_to_header() relies on the SDK's hgbin2c. Report the case as not run
# instead of failing when the installed SDK does not ship that tool.
get_filename_component(_hg_bin_dir "${CMAKE_HG_COMPILER}" DIRECTORY)
find_program(HGGC_BIN2C_EXECUTABLE hgbin2c HINTS "${_hg_bin_dir}")
mark_as_advanced(HGGC_BIN2C_EXECUTABLE)
if(NOT HGGC_BIN2C_EXECUTABLE)
  set_tests_properties(fatbin_to_header PROPERTIES DISABLED TRUE)
  message(STATUS "fatbin_to_header: disabled, hgbin2c not found in ${_hg_bin_dir} or PATH")
endif()

# --- hgcc_add_rdc_library() — device code in a STATIC library ---
hggc_add_feature_test(rdc_library NEEDS_DEVICE
  TEST_COMMAND "${_ft_bin_root}/rdc_library/test_rdc_lib_user")

# --- CMAKE_HG_RUNTIME_LIBRARY=NONE + explicit runtime linking ---
hggc_add_feature_test(runtime_library_none NEEDS_DEVICE
  BUILD_OPTIONS -DCMAKE_HG_RUNTIME_LIBRARY=NONE
  TEST_COMMAND "${_ft_bin_root}/runtime_library_none/test_runtime_none")

# --- CMAKE_HG_COMPILER_LAUNCHER (the ccache/sccache hook) ---
# Invoked via `sh` so the case does not depend on the script's exec bit surviving
# whatever transport carried the checkout (scp/zip/git without the mode recorded).
hggc_add_feature_test(compiler_launcher NEEDS_DEVICE
  BUILD_OPTIONS
    "-DCMAKE_HG_COMPILER_LAUNCHER=sh ${CMAKE_CURRENT_SOURCE_DIR}/compiler_launcher/launcher.sh"
  TEST_COMMAND "${_ft_bin_root}/compiler_launcher/test_launcher_probe")

# --- FindHGGCToolkit imported targets and their properties ---
hggc_add_feature_test(toolkit_targets)

# --- link-level use of an HGGC::* imported target ---
# Pure host code: hgrtcVersion() needs no PPU device, so this one always runs.
hggc_add_feature_test(link_hgrtc
  TEST_COMMAND "${_ft_bin_root}/link_hgrtc/test_link_hgrtc")

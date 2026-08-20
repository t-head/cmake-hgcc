cmake_minimum_required(VERSION 3.20)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake/Modules")

set(CMAKE_HG_STANDARD 17)

project(cmake_hgcc_tests LANGUAGES CXX HG)

include(HGGCUtilities)
find_package(HGGCToolkit REQUIRED)

enable_testing()

message(STATUS "")
message(STATUS "=== cmake-hgcc test suite ===")
message(STATUS "HG compiler:       ${CMAKE_HG_COMPILER}")
message(STATUS "HG version:        ${CMAKE_HG_COMPILER_VERSION}")
message(STATUS "Toolkit root:      ${CMAKE_HG_TOOLKIT_ROOT}")
message(STATUS "Host link launcher:${CMAKE_HG_HOST_LINK_LAUNCHER}")
message(STATUS "Implicit libs:     ${CMAKE_HG_HOST_IMPLICIT_LINK_LIBRARIES}")
message(STATUS "Implicit lib dirs: ${CMAKE_HG_HOST_IMPLICIT_LINK_DIRECTORIES}")
message(STATUS "Toolkit version:   ${HGGCToolkit_VERSION}")
message(STATUS "")

# --- Test 1: Single .hg file ---
add_executable(test_simple test_simple.hg)
add_test(NAME simple COMMAND test_simple)

# --- Test 2: Mixed .hg + .cpp ---
add_executable(test_mixed test_device.hg test_host.cpp)
add_test(NAME mixed COMMAND test_mixed)

# --- Test 3: Fatbin generation ---
hgcc_add_fatbin(test_fatbin test_fatbin_kernel.hg)
add_test(NAME fatbin_exists COMMAND ${CMAKE_COMMAND} -E
  md5sum ${CMAKE_CURRENT_BINARY_DIR}/test_fatbin.fatbin)

# --- Test 4: RDC — pure .hg ---
hgcc_add_rdc_executable(test_rdc_pure test_rdc_helper.hg test_rdc_kernel.hg test_rdc_pure_main.hg)
add_test(NAME rdc_pure COMMAND test_rdc_pure)

# --- Test 5: RDC — mixed .hg + .cpp ---
hgcc_add_rdc_executable(test_rdc_mixed test_rdc_helper.hg test_rdc_kernel.hg test_rdc_main.cpp)
add_test(NAME rdc_mixed COMMAND test_rdc_mixed)

# --- Test 6: RDC via hgcc_enable_rdc ---
add_executable(test_rdc_enable test_rdc_helper.hg test_rdc_kernel.hg test_rdc_main.cpp)
hgcc_enable_rdc(test_rdc_enable)
add_test(NAME rdc_enable COMMAND test_rdc_enable)

# --- Test 7: .cu extension compatibility (requires CMAKE_HG_ENABLE_CU_EXTENSION=ON) ---
if(CMAKE_HG_ENABLE_CU_EXTENSION)
  add_executable(test_cu_compat test_cu_compat.cu)
  add_test(NAME cu_compat COMMAND test_cu_compat)
endif()

# --- Test 8: Shared library ---
add_library(test_shlib SHARED test_shared_lib.hg)
add_executable(test_shared_user test_shared_main.cpp)
target_link_libraries(test_shared_user PRIVATE test_shlib)
set_target_properties(test_shared_user PROPERTIES
  BUILD_RPATH "${CMAKE_CURRENT_BINARY_DIR}")
add_test(NAME shared_lib COMMAND test_shared_user)

# --- Print discovered targets ---
foreach(_lib toolkit hggcrt hggc hgrtc hgrtc_builtins hgvm hgJitLink hgJitLink_static acblas acblasLt acfft acrand acdnn acsparse acsolver pccl)
  if(TARGET HGGC::${_lib})
    message(STATUS "  Found HGGC::${_lib}")
  else()
    message(STATUS "  NOT found: HGGC::${_lib}")
  endif()
endforeach()
message(STATUS "")

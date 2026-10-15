cmake_minimum_required(VERSION 3.20)

# Covers CMAKE_HG_RUNTIME_LIBRARY=NONE: the HGGC runtime must no longer be
# injected implicitly, leaving the project free to link it explicitly.
#
# The target is deliberately a mixed HG + CXX one whose linker language stays
# CXX — that is the only configuration where CMAKE_HG_IMPLICIT_LINK_LIBRARIES is
# consumed. A pure HG target is linked by hgcc, which pulls the runtime itself.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules \
#         -DCMAKE_HG_RUNTIME_LIBRARY=NONE -S . -B build
#   cmake --build build

project(hggc_runtime_library_none LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)

if(NOT CMAKE_HG_RUNTIME_LIBRARY STREQUAL "NONE")
  message(FATAL_ERROR
    "this project must be configured with -DCMAKE_HG_RUNTIME_LIBRARY=NONE, "
    "got '${CMAKE_HG_RUNTIME_LIBRARY}'")
endif()

if(NOT CMAKE_HG_IMPLICIT_LINK_LIBRARIES STREQUAL "")
  message(FATAL_ERROR
    "CMAKE_HG_RUNTIME_LIBRARY=NONE must clear CMAKE_HG_IMPLICIT_LINK_LIBRARIES, "
    "got '${CMAKE_HG_IMPLICIT_LINK_LIBRARIES}'")
endif()

message(STATUS "CMAKE_HG_RUNTIME_LIBRARY:        ${CMAKE_HG_RUNTIME_LIBRARY}")
message(STATUS "CMAKE_HG_IMPLICIT_LINK_LIBRARIES: (empty, as expected)")

# Same mixed sources as test/'s mixed case.
set(_shared_src "${CMAKE_CURRENT_SOURCE_DIR}/../../../../test")

add_executable(test_runtime_none
  "${_shared_src}/test_device.hg"
  "${_shared_src}/test_host.cpp")

# Without this the link fails on hggcMalloc &co — that is the point of NONE.
target_link_libraries(test_runtime_none PRIVATE HGGC::toolkit)

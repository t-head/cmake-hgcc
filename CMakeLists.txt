cmake_minimum_required(VERSION 3.20)
project(cmake-hgcc VERSION 1.0.0 LANGUAGES NONE)

include(CMakePackageConfigHelpers)

set(HGCC_CMAKE_MODULE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")

# --- Install destinations ---
set(HGCC_INSTALL_CMAKE_DIR "share/cmake/cmake-hgcc" CACHE STRING
  "Installation directory for CMake module files (relative to CMAKE_INSTALL_PREFIX)")
set(HGCC_INSTALL_MODULE_DIR "${HGCC_INSTALL_CMAKE_DIR}/Modules")

# --- Install cmake language modules ---
install(
  FILES
    cmake/Modules/CMakeDetermineHGCompiler.cmake
    cmake/Modules/CMakeHGCompiler.cmake.in
    cmake/Modules/CMakeHGInformation.cmake
    cmake/Modules/CMakeTestHGCompiler.cmake
    cmake/Modules/FindHGGCToolkit.cmake
    cmake/Modules/HGGCUtilities.cmake
  DESTINATION "${HGCC_INSTALL_MODULE_DIR}")

install(
  FILES
    cmake/Modules/Compiler/HGCC-HG.cmake
  DESTINATION "${HGCC_INSTALL_MODULE_DIR}/Compiler")

# --- Generate and install config package ---
configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake-hgccConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/cmake-hgccConfig.cmake"
  INSTALL_DESTINATION "${HGCC_INSTALL_CMAKE_DIR}")

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/cmake-hgccConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion)

install(
  FILES
    "${CMAKE_CURRENT_BINARY_DIR}/cmake-hgccConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake-hgccConfigVersion.cmake"
  DESTINATION "${HGCC_INSTALL_CMAKE_DIR}")

# --- Install license files ---
install(
  FILES LICENSE NOTICE
  DESTINATION "share/doc/cmake-hgcc")

message(STATUS "cmake-hgcc ${PROJECT_VERSION}: modules in ${HGCC_CMAKE_MODULE_DIR}")
message(STATUS "cmake-hgcc: install to ${CMAKE_INSTALL_PREFIX}/${HGCC_INSTALL_CMAKE_DIR}")

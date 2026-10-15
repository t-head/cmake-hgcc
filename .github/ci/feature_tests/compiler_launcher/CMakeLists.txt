cmake_minimum_required(VERSION 3.20)

# Covers CMAKE_HG_COMPILER_LAUNCHER: the launcher must be prepended to the HG
# compile rule (the ccache/sccache hook).
#
# Instead of depending on ccache being installed, launcher.sh injects a macro
# into the real compiler invocation and test_launcher_probe.hg fails to compile
# unless that macro is present. The check is therefore deterministic and also
# proves the launcher wraps the compiler rather than replacing it.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules \
#         "-DCMAKE_HG_COMPILER_LAUNCHER=sh $PWD/launcher.sh" -S . -B build
#   cmake --build build
# (The `sh` prefix makes the script's exec bit irrelevant.)

project(hggc_compiler_launcher LANGUAGES CXX HG)

if(NOT CMAKE_HG_COMPILER_LAUNCHER)
  message(FATAL_ERROR
    "this project must be configured with "
    "-DCMAKE_HG_COMPILER_LAUNCHER='sh <path>/launcher.sh'")
endif()

message(STATUS "CMAKE_HG_COMPILER_LAUNCHER: ${CMAKE_HG_COMPILER_LAUNCHER}")

add_executable(test_launcher_probe test_launcher_probe.hg)

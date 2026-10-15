cmake_minimum_required(VERSION 3.20)

# Covers hgcc_set_standard(): a per-target C++ standard must override the
# project-wide CMAKE_HG_STANDARD for HG sources.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules -S . -B build
#   cmake --build build

set(CMAKE_HG_STANDARD 17)

project(hggc_set_standard LANGUAGES CXX HG)

include(HGGCUtilities)

# Differential check: the same source is compiled twice. Only the second target
# gets hgcc_set_standard(), so a no-op implementation fails to build it while a
# leaking implementation fails the first one.
add_executable(probe_default test_std_probe.hg)
target_compile_definitions(probe_default PRIVATE EXPECT_CXX17)

add_executable(probe_cxx14 test_std_probe.hg)
target_compile_definitions(probe_cxx14 PRIVATE EXPECT_CXX14)
hgcc_set_standard(probe_cxx14 14)

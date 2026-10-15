cmake_minimum_required(VERSION 3.20)

# Covers link-level consumption of an HGGC::* imported target: include directory
# propagation (hgrtc.h), library propagation and the runtime loader actually
# finding the .so. Nothing in test/ links an HGGC::* target.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules -S . -B build
#   cmake --build build

project(hggc_link_hgrtc LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)

if(NOT TARGET HGGC::hgrtc)
  message(FATAL_ERROR
    "HGGC::hgrtc was not created by FindHGGCToolkit — SDK at "
    "'${HGGCToolkit_ROOT}' has no hgrtc library")
endif()

add_executable(test_link_hgrtc test_link_hgrtc.cpp)

# No HG sources here: the include dir and the library must come from the imported
# target alone, which is exactly what is being verified.
target_link_libraries(test_link_hgrtc PRIVATE HGGC::hgrtc)

# Distributions that default to --as-needed would drop the DT_NEEDED entry and
# reduce this case to a compile check; keep the runtime dependency observable.
target_link_options(test_link_hgrtc PRIVATE "LINKER:--no-as-needed")

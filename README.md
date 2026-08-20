# cmake-hgcc

CMake language support for HGGC via the hgcc compiler, providing a native CMake experience aligned with CMake's built-in language support.

## Contents

- [Terminology](#terminology)
- [Quick Start](#quick-start)
- [CUDA Migration](#cuda-migration)
- [Variables Reference](#variables-reference)
- [Imported Targets](#imported-targets)
- [Utility Functions](#utility-functions)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Requirements](#requirements)
- [License](#license)

## Terminology

**HGGC** and **hgcc** are related but distinct:

- **HGGC** (HeteroGeneous General-purpose Computing) — a parallel programming model and
  language for heterogeneous computing systems.
- **hgcc** — the HGGC C/C++ Compiler, the compiler that builds HGGC programs.

## Quick Start

cmake-hgcc ships a set of CMake language modules under `cmake/Modules`. Make them
visible to CMake, then use `HG` like any built-in language.

**1. Register the modules.** Either source the bundled helper or point
`CMAKE_MODULE_PATH` at the modules yourself:

```bash
# Sets CMAKE_MODULE_PATH (and CMAKE_PREFIX_PATH) to the bundled modules.
source /path/to/cmake-hgcc/envsetup.sh
```

```cmake
# ...or, without envsetup.sh, add the module directory manually:
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")
```

> `envsetup.sh` is cmake-hgcc's own helper — it only registers the CMake modules.
> The `hgcc` compiler itself must already be reachable via `PATH`, the `HGCC`
> variable, or `PPU_SDK` (see [Requirements](#requirements)).

**2. Write a minimal `CMakeLists.txt`:**

```cmake
cmake_minimum_required(VERSION 3.20)

project(myapp LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)

add_executable(myapp main.hg helper.cpp)
target_link_libraries(myapp PRIVATE HGGC::toolkit)
```

**3. Build and test:**

```bash
cmake -B build
cmake --build build
ctest --test-dir build
```

## CUDA Migration

For users with existing CUDA CMake projects, cmake-hgcc provides a migration path to
ease the transition to HGGC. Because it follows standard CMake conventions, most projects
can switch over with only minor edits.

See the [migration guide](docs/MIGRATION.md) for the CUDA→HGGC variable/target mapping,
step-by-step migration examples, and the automated migration tool.

## Variables Reference

### Compiler

| Variable | Description | Example |
|----------|-------------|---------|
| `CMAKE_HG_COMPILER` | Path to hgcc | `/usr/local/PPU_SDK/bin/hgcc` |
| `CMAKE_HG_COMPILER_VERSION` | Compiler version | `2.1.1` |
| `CMAKE_HG_HOST_COMPILER` | Host C++ compiler | `/usr/bin/g++` |
| `CMAKE_HG_HOST_LINK_LAUNCHER` | Host linker | `/usr/bin/g++` |
| `CMAKE_HG_ARCHITECTURES` | Target GPU architectures | `ppu_10;ppu_15` |
| `CMAKE_HG_STANDARD` | C++ standard for HG sources | `17` |
| `CMAKE_HG_STANDARD_REQUIRED` | Error if `CMAKE_HG_STANDARD` is unsupported | `ON` |
| `CMAKE_HG_EXTENSIONS` | Use compiler extension variant of the C++ standard (set before `project()`/`enable_language(HG)`) | `ON` |
| `CMAKE_HG_SEPARABLE_COMPILATION` | Enable RDC for all HG targets (set before `project()`/`enable_language(HG)`); mixed HG+CXX targets also need `LINKER_LANGUAGE HG` | `OFF` |
| `CMAKE_HG_FLAGS` | Global compile flags | |
| `CMAKE_HG_FLAGS_DEBUG` | Debug flags | `-g -G` |
| `CMAKE_HG_FLAGS_RELEASE` | Release flags | `-O3 -DNDEBUG` |
| `CMAKE_HG_COMPILER_LAUNCHER` | Compile cache (ccache/sccache) | `ccache` |
| `CMAKE_HG_RUNTIME_LIBRARY` | Runtime linkage (`SHARED` / `NONE`) | `SHARED` |
| `CMAKE_HG_ENABLE_CU_EXTENSION` | Treat `.cu` files as HG sources | `OFF` |
| `CMAKE_HG_COMPILER_FORCED` | Skip the compiler sanity test | `TRUE` |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HGCC` | Path to hgcc compiler |
| `HGCCHOSTCXX` | Host C++ compiler |
| `HGFLAGS` | Default compile flags |
| `PPU_SDK` | SDK root directory |
| `CMAKE_HG_COMPILER_LAUNCHER` | Compiler launcher — initializes the CMake variable of the same name if that variable isn't set |

### Toolkit (`find_package(HGGCToolkit)`)

| Variable | Description |
|----------|-------------|
| `HGGCToolkit_FOUND` | Whether the SDK was found |
| `HGGCToolkit_VERSION` | SDK version |
| `HGGCToolkit_ROOT` | SDK root directory |
| `HGGCToolkit_INCLUDE_DIR` | Header directory |
| `HGGCToolkit_LIBRARY_DIR` | Library directory |
| `HGGCToolkit_BIN_DIR` | Binary directory |

SDK root search order: `HGGCToolkit_ROOT` (CMake or environment variable — also set as
a result), `CMAKE_HG_TOOLKIT_ROOT` (derived from the compiler path when the HG language
is enabled, overridable), `PPU_SDK` environment variable, then `/usr/local/PPU_SDK`.

## Imported Targets

| Target | Library | Purpose |
|--------|---------|---------|
| `HGGC::toolkit` | (interface) | Umbrella — links runtime + includes |
| `HGGC::hggcrt` | libhggcrt1.so | GPU runtime |
| `HGGC::hggc` | libhggc.so | Driver library |
| `HGGC::hgrtc` | libhgrtc.so | Runtime compilation |
| `HGGC::hgrtc_builtins` | libhgrtc_builtins.so | Runtime compilation builtins |
| `HGGC::hgvm` | libhgvm.so | VM API |
| `HGGC::hgJitLink` | libhgJitLink.so | JIT linker |
| `HGGC::hgJitLink_static` | libhgJitLink_static.a | JIT linker (static) |
| `HGGC::acblas` | libacblas.so | BLAS |
| `HGGC::acblasLt` | libacblasLt.so | BLAS (lightweight) |
| `HGGC::acfft` | libacfft.so | FFT |
| `HGGC::acrand` | libacrand.so | Random numbers |
| `HGGC::acdnn` | libacdnn.so | DNN |
| `HGGC::acsparse` | libacsparse.so | Sparse matrices |
| `HGGC::acsolver` | libacsolver.so | Linear solvers |
| `HGGC::hgjpeg` | libhgjpeg.so | JPEG decode/encode |
| `HGGC::pccl` | libpccl.so | Collective communication |

## Utility Functions

These helpers are provided by `include(HGGCUtilities)`:

```cmake
# RDC (Separable Compilation)
add_executable(myapp a.hg b.hg host.cpp)
hgcc_enable_rdc(myapp)

# Equivalent to the above; mixed HG+CXX targets need LINKER_LANGUAGE HG
# so hgcc performs the device link phase:
set_target_properties(myapp PROPERTIES
  HG_SEPARABLE_COMPILATION ON
  LINKER_LANGUAGE HG)

# Or enable RDC for all HG targets — must be set before
# project()/enable_language(HG):
#   set(CMAKE_HG_SEPARABLE_COMPILATION ON)

# Or use the shortcut:
hgcc_add_rdc_executable(myapp a.hg b.hg host.cpp)
hgcc_add_rdc_library(mylib STATIC a.hg b.hg)

# Fatbin generation
hgcc_add_fatbin(my_kernel kernel.hg
  ARCHITECTURES ppu_15
  INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/include
  DEPENDS some_generated_header.h)

# Convert fatbin to C header
hgcc_fatbin_to_header(${my_kernel_OUTPUT} kernel_fatbin.h)

# Set C++ standard for HG sources in a specific target
hgcc_set_standard(myapp 17)
```

## Testing

The `test/` directory contains a CTest suite covering single `.hg`, mixed `.hg` + `.cpp`,
fatbin generation, RDC (pure, mixed, and via `hgcc_enable_rdc`), `.cu` compatibility, and
shared libraries.

```bash
bash scripts/run_tests.sh                              # hgcc on PATH
DOCKER_CONTAINER=my_dev bash scripts/run_tests.sh      # run inside a container
```

The runner configures and builds with both `Unix Makefiles` and `Ninja` (when available),
then runs `ctest`.

## Troubleshooting

**"Could not find hgcc compiler"**
- `source $PPU_SDK/envsetup.sh` or `-DCMAKE_HG_COMPILER=/path/to/hgcc`

**".cpp files can't find hggc_runtime.h"**
- `target_link_libraries(target PRIVATE HGGC::toolkit)`

**"Undefined reference to hggcMalloc" in mixed HG+CXX targets**
- Non-RDC: should resolve automatically (implicit link libraries). Check
  `CMAKE_HG_IMPLICIT_LINK_LIBRARIES`
- RDC: use `hgcc_enable_rdc(target)`

**"CMAKE_HG_STANDARD=XX is not supported"**
- Supported values: 11, 14, 17, 20

## Requirements

- CMake >= 3.20
- hgcc (PPU SDK)
- Linux (x86_64 or aarch64)

## License

cmake-hgcc provides CMake language support for the HGGC compiler, developed by
T-Head (Shanghai) Semiconductor Co., Ltd. and licensed under the Apache License,
Version 2.0.

See the [LICENSE](LICENSE) and [NOTICE](NOTICE) files for more information.

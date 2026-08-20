# CUDA to HGGC Migration Guide

> Part of the cmake-hgcc documentation. For the quick start, variables reference, and
> imported targets, see the [main README](../README.md).

For users with existing CUDA CMake projects, cmake-hgcc provides a migration path to
ease the move to HGGC. It follows standard CMake conventions, so most projects can
transition with only minor edits — the overall CMake structure and usage stay consistent.

This guide covers:

- A [feature comparison](#feature-comparison-with-cmake-cuda) between CMake's CUDA
  support and cmake-hgcc.
- [Step-by-step migration](#migration-steps) from CUDA to HGGC.
- An [automated migration tool](#automated-migration-tool).
- An [appendix](#appendix-migrating-from-the-hgcc-add_custom_command-pattern) for
  migrating projects off the manual `add_custom_command` pattern.

## Feature Comparison with CMake CUDA

| Feature | CMake CUDA | cmake-hgcc |
|---------|-----------|------------|
| Language enable | `LANGUAGES CUDA` | `LANGUAGES HG` |
| Source extension | `.cu` | `.hg` |
| Compiler | `nvcc` | `hgcc` |
| Compilation | `nvcc -c` | `hgcc -x hg -c` |
| Linking | Host compiler + implicit libs | Host compiler + implicit libs |
| Mixed sources | `add_executable(app f.cu g.cpp)` | `add_executable(app f.hg g.cpp)` |
| Toolkit discovery | `find_package(CUDAToolkit)` | `find_package(HGGCToolkit)` |
| Runtime target | `CUDA::cudart` | `HGGC::hggcrt` |
| Umbrella target | `CUDA::toolkit` | `HGGC::toolkit` |
| Architecture | `CMAKE_CUDA_ARCHITECTURES` | `CMAKE_HG_ARCHITECTURES` |
| C++ standard | `CMAKE_CUDA_STANDARD` | `CMAKE_HG_STANDARD` |
| Host compiler | `CMAKE_CUDA_HOST_COMPILER` | `CMAKE_HG_HOST_COMPILER` |
| Separable compilation | `CUDA_SEPARABLE_COMPILATION ON` | `hgcc_enable_rdc(target)`, `HG_SEPARABLE_COMPILATION` property, or global `CMAKE_HG_SEPARABLE_COMPILATION` |
| Fatbin | built-in | `hgcc_add_fatbin()` |
| PIC/PIE | `-Xcompiler=-fPIC` | `-Xcompiler=-fPIC` |
| Dependency tracking | `-MD -MF` | `-MD -MF` |
| Forward flags | `-forward-unknown-to-host-compiler` | `-forward-unknown-to-host-compiler` |
| Device link | `CMAKE_CUDA_DEVICE_LINK_*` | `CMAKE_HG_DEVICE_LINK_*` |
| IPO/LTO | `-dlto` | `-dlto` |
| Warning as error | `-Werror all-warnings` | `-Werror all-warnings` |
| Compiler launcher | `CMAKE_CUDA_COMPILER_LAUNCHER` | `CMAKE_HG_COMPILER_LAUNCHER` |
| Response file | `--options-file` | `--options-file` |
| Config package | built-in | `find_package(cmake-hgcc CONFIG)` |
| Generators | Makefiles, Ninja, VS | Makefiles, Ninja |

## Migration Steps

### Step 1: CMakeLists.txt header

```cmake
# CUDA (before)
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX CUDA)
find_package(CUDAToolkit REQUIRED)

# HGGC (after)
cmake_minimum_required(VERSION 3.20)
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")  # or: source envsetup.sh
project(myapp LANGUAGES CXX HG)
find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)  # if using RDC or fatbin functions
```

### Step 2: Source files

hgcc supports both `.hg` and `.cu` extensions. With the `CMAKE_HG_ENABLE_CU_EXTENSION`
option enabled, **no source renaming is needed** — `.cu` files are compiled directly by hgcc:

```cmake
# Enable .cu support before project()
set(CMAKE_HG_ENABLE_CU_EXTENSION ON)

project(myapp LANGUAGES CXX HG)

# Use .cu files directly, no renaming needed
add_executable(myapp kernel.cu host.cpp)
```

Without this option (default), only `.hg` files are recognized as HG sources — suitable
for new projects or projects that have already been renamed.

CUDA Runtime/Driver API calls in source must be replaced with the corresponding HGGC APIs — see the
**HGGC Programming Guide**.

> **Note**: With `.cu` support enabled, do not also enable CMake's built-in `CUDA`
> language, or the extensions will conflict.

### Step 3: CMake variable and target name mapping

**Variable replacement table** — a global find-and-replace suffices:

| CUDA | HGGC | Description |
|------|------|-------------|
| `CMAKE_CUDA_COMPILER` | `CMAKE_HG_COMPILER` | Compiler path |
| `CMAKE_CUDA_ARCHITECTURES` | `CMAKE_HG_ARCHITECTURES` | GPU architectures |
| `CMAKE_CUDA_STANDARD` | `CMAKE_HG_STANDARD` | C++ standard |
| `CMAKE_CUDA_FLAGS` | `CMAKE_HG_FLAGS` | Compile flags |
| `CMAKE_CUDA_HOST_COMPILER` | `CMAKE_HG_HOST_COMPILER` | Host compiler |
| `CUDAFLAGS` (env) | `HGFLAGS` (env) | Environment variable |
| `CUDA_SEPARABLE_COMPILATION` | → `hgcc_enable_rdc(target)` | Separable compilation |

**Imported target replacement table**:

| CUDA | HGGC |
|------|------|
| `CUDA::toolkit` | `HGGC::toolkit` |
| `CUDA::cudart` | `HGGC::hggcrt` |
| `CUDA::cuda_driver` | `HGGC::hggc` |
| `CUDA::nvrtc` | `HGGC::hgrtc` |
| `CUDA::cublas` | `HGGC::acblas` |
| `CUDA::cublasLt` | `HGGC::acblasLt` |
| `CUDA::cufft` | `HGGC::acfft` |
| `CUDA::curand` | `HGGC::acrand` |
| `CUDA::cusparse` | `HGGC::acsparse` |
| `CUDA::cusolver` | `HGGC::acsolver` |
| `CUDA::cudnn` | `HGGC::acdnn` |
| `CUDA::nccl` | `HGGC::pccl` |
| `CUDA::nvJitLink` | `HGGC::hgJitLink` |

### Step 4: Target architectures

PPU architectures are specified via `CMAKE_HG_ARCHITECTURES`. Available values:

| Architecture | Description |
|------|-------------|
| `ppu_10` | PPU 1.0 |
| `ppu_15` | PPU 1.5 |
| `vm_10` | VM 1.0 (emulation) |
| `vm_15` | VM 1.5 (emulation) |
| `all` | All architectures |
| `all-ppu` | All PPU physical architectures |
| `all-vm` | All VM emulation architectures |

```cmake
# Single architecture
set(CMAKE_HG_ARCHITECTURES ppu_15)

# Multiple architectures
set(CMAKE_HG_ARCHITECTURES ppu_10 ppu_15)

# All architectures
set(CMAKE_HG_ARCHITECTURES all)
```

When not specified, hgcc uses its default architecture. Use `hgcc --list-gpu-arch` to
query the architectures supported by the current SDK.

### Step 5: Separable compilation (RDC)

```cmake
# CUDA
add_executable(myapp a.cu b.cu main.cpp)
set_target_properties(myapp PROPERTIES CUDA_SEPARABLE_COMPILATION ON)

# HGGC
add_executable(myapp a.hg b.hg main.cpp)
hgcc_enable_rdc(myapp)
```

### Complete migration example

```cmake
# ============== Original CUDA project ==============
cmake_minimum_required(VERSION 3.20)
project(matmul LANGUAGES CXX CUDA)

find_package(CUDAToolkit REQUIRED)

set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_ARCHITECTURES 70)

add_executable(matmul
  matmul_kernel.cu
  matmul_host.cpp
  main.cpp)

target_link_libraries(matmul PRIVATE
  CUDA::cublas
  CUDA::cudart)

set_target_properties(matmul PROPERTIES
  CUDA_SEPARABLE_COMPILATION ON)
```

```cmake
# ============== After HGGC migration ==============
cmake_minimum_required(VERSION 3.20)
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")

set(CMAKE_HG_ENABLE_CU_EXTENSION ON)  # keep .cu sources without renaming

project(matmul LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)

set(CMAKE_HG_STANDARD 17)
set(CMAKE_HG_ARCHITECTURES ppu_15)

add_executable(matmul
  matmul_kernel.cu        # no .cu renaming needed
  matmul_host.cpp
  main.cpp)

target_link_libraries(matmul PRIVATE
  HGGC::acblas
  HGGC::toolkit)

hgcc_enable_rdc(matmul)
```

### Notes

- When `.cpp` files `#include` SDK headers, link `HGGC::toolkit` to get the include
  paths (handled implicitly by CMake for CUDA; must be explicit for HGGC).
- Kernel syntax (`__global__`, `<<<>>>`, `dim3`, etc.) is fully compatible — no changes
  needed.
- Runtime/Driver API calls must be replaced — see the HGGC Programming Guide.

## Automated migration tool

The `scripts/cuda_to_hgcc.sh` script batch-replaces CUDA variable and target names in
CMakeLists.txt:

```bash
# Preview changes (no file modification)
bash scripts/cuda_to_hgcc.sh /path/to/cuda-project

# Apply changes (originals backed up as *.cuda_bak)
bash scripts/cuda_to_hgcc.sh /path/to/cuda-project --apply
```

The script handles name replacement in CMakeLists.txt / *.cmake files. The following
CMake-level steps still need manual review:

1. **Architecture values**: replace with PPU target architectures (see the table above).
2. **MODULE_PATH**: `source cmake-hgcc/envsetup.sh` or set it in CMakeLists.txt.
3. **RDC**: replace the `CUDA_SEPARABLE_COMPILATION` property with a
   `hgcc_enable_rdc(target)` call.
4. **Mixed-source targets**: add `target_link_libraries(... HGGC::toolkit)` to targets
   containing `.cpp`.
5. **`include(HGGCUtilities)`**: required when using RDC or fatbin functions.

For source-level changes (API and header replacement), see the HGGC Programming Guide.

## Appendix: Migrating from the hgcc `add_custom_command` pattern

Projects that use `project(xxx NONE)` + `add_custom_command` to invoke hgcc manually
should also migrate to cmake-hgcc. Typical change:

```cmake
# Before (project NONE + custom command, ~19 lines per target):
project(vectorAdd_hgcc NONE)
set(SRC vectorAdd.hg)
set(OUT ${CMAKE_CURRENT_BINARY_DIR}/vectorAdd.out)
add_custom_command(OUTPUT ${OUT}
    COMMAND hgcc -x hg ${SRC} -I ${COMMON_DIR} -o ${OUT}
    DEPENDS ${SRC})
add_custom_target(vectorAdd ALL DEPENDS ${OUT})

# After (standard CMake, 3 lines):
project(vectorAdd LANGUAGES HG)
add_executable(vectorAdd vectorAdd.hg)
target_include_directories(vectorAdd PRIVATE ${COMMON_DIR})
```

**Link SDK libraries** (e.g. hgrtc, acblas):
```cmake
target_link_libraries(myapp PRIVATE HGGC::hgrtc HGGC::acblas)
```

**Batch tests with foreach**:
```cmake
foreach(_test test_a test_b test_c)
  add_executable(${_test} ${_test}.hg)
  target_include_directories(${_test} PRIVATE ${COMMON_DIR})
endforeach()
```

**Fatbin generation**:
```cmake
hgcc_add_fatbin(my_kernel kernel.hg INCLUDE_DIRECTORIES ${COMMON_DIR})
```

**Automate it**: `python3 scripts/migrate_cmake.py /path/to/project` performs this
`add_custom_command` → cmake-hgcc migration automatically (originals backed up to `.bak`).

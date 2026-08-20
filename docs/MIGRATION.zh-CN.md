# CUDA 到 HGGC 迁移指南

> 本文是 cmake-hgcc 文档的一部分。快速开始、变量参考和 imported targets
> 请见[主 README](../README.zh-CN.md)。

对于已有 CUDA CMake 项目的用户,cmake-hgcc 提供了一条迁移路径,方便向 HGGC 过渡。
由于遵循标准 CMake 惯例,大多数项目只需少量修改即可完成迁移——整体 CMake 结构与用法
保持一致。

本指南内容包括:

- CMake CUDA 支持与 cmake-hgcc 的[功能对比](#与-cmake-cuda-的功能对比)。
- 从 CUDA 到 HGGC 的[逐步迁移](#迁移步骤)。
- [自动化迁移工具](#自动化迁移工具)。
- 将基于手工 `add_custom_command` 写法的项目迁出的[附录](#附录从-hgcc-add_custom_command-写法迁移)。

## 与 CMake CUDA 的功能对比

| 功能 | CMake CUDA | cmake-hgcc |
|---------|-----------|------------|
| 语言启用 | `LANGUAGES CUDA` | `LANGUAGES HG` |
| 源文件扩展名 | `.cu` | `.hg` |
| 编译器 | `nvcc` | `hgcc` |
| 编译 | `nvcc -c` | `hgcc -x hg -c` |
| 链接 | 宿主编译器 + 隐式库 | 宿主编译器 + 隐式库 |
| 混合源 | `add_executable(app f.cu g.cpp)` | `add_executable(app f.hg g.cpp)` |
| Toolkit 发现 | `find_package(CUDAToolkit)` | `find_package(HGGCToolkit)` |
| 运行时 target | `CUDA::cudart` | `HGGC::hggcrt` |
| 聚合 target | `CUDA::toolkit` | `HGGC::toolkit` |
| 架构 | `CMAKE_CUDA_ARCHITECTURES` | `CMAKE_HG_ARCHITECTURES` |
| C++ 标准 | `CMAKE_CUDA_STANDARD` | `CMAKE_HG_STANDARD` |
| 宿主编译器 | `CMAKE_CUDA_HOST_COMPILER` | `CMAKE_HG_HOST_COMPILER` |
| 分离编译 | `CUDA_SEPARABLE_COMPILATION ON` | `hgcc_enable_rdc(target)`、`HG_SEPARABLE_COMPILATION` 属性或全局 `CMAKE_HG_SEPARABLE_COMPILATION` |
| Fatbin | 内置 | `hgcc_add_fatbin()` |
| PIC/PIE | `-Xcompiler=-fPIC` | `-Xcompiler=-fPIC` |
| 依赖跟踪 | `-MD -MF` | `-MD -MF` |
| 选项转发 | `-forward-unknown-to-host-compiler` | `-forward-unknown-to-host-compiler` |
| 设备链接 | `CMAKE_CUDA_DEVICE_LINK_*` | `CMAKE_HG_DEVICE_LINK_*` |
| IPO/LTO | `-dlto` | `-dlto` |
| 警告视为错误 | `-Werror all-warnings` | `-Werror all-warnings` |
| 编译器启动器 | `CMAKE_CUDA_COMPILER_LAUNCHER` | `CMAKE_HG_COMPILER_LAUNCHER` |
| 响应文件 | `--options-file` | `--options-file` |
| Config 包 | 内置 | `find_package(cmake-hgcc CONFIG)` |
| 生成器 | Makefiles, Ninja, VS | Makefiles, Ninja |

## 迁移步骤

### 第 1 步:CMakeLists.txt 头部

```cmake
# CUDA(迁移前)
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX CUDA)
find_package(CUDAToolkit REQUIRED)

# HGGC(迁移后)
cmake_minimum_required(VERSION 3.20)
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")  # 或:source envsetup.sh
project(myapp LANGUAGES CXX HG)
find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)  # 使用 RDC 或 fatbin 函数时需要
```

### 第 2 步:源文件

hgcc 同时支持 `.hg` 和 `.cu` 两种扩展名。开启 `CMAKE_HG_ENABLE_CU_EXTENSION` 选项后,
**无需重命名源文件**——`.cu` 文件直接由 hgcc 编译:

```cmake
# 在 project() 之前开启 .cu 支持
set(CMAKE_HG_ENABLE_CU_EXTENSION ON)

project(myapp LANGUAGES CXX HG)

# .cu 文件直接使用,无需改名
add_executable(myapp kernel.cu host.cpp)
```

不开启此选项时(默认),仅 `.hg` 文件被识别为 HG 源文件——适用于新项目或已完成改名的项目。

源码中的 CUDA Runtime/Driver API 调用需替换为 HGGC 对应 API——详见 **HGGC 编程指南**。

> **注意**:开启 `.cu` 支持后,不要同时启用 CMake 内置的 `CUDA` 语言,否则扩展名会冲突。

### 第 3 步:CMake 变量与 target 名称映射

**变量替换表**——全局查找替换即可:

| CUDA | HGGC | 说明 |
|------|------|-------------|
| `CMAKE_CUDA_COMPILER` | `CMAKE_HG_COMPILER` | 编译器路径 |
| `CMAKE_CUDA_ARCHITECTURES` | `CMAKE_HG_ARCHITECTURES` | GPU 架构 |
| `CMAKE_CUDA_STANDARD` | `CMAKE_HG_STANDARD` | C++ 标准 |
| `CMAKE_CUDA_FLAGS` | `CMAKE_HG_FLAGS` | 编译选项 |
| `CMAKE_CUDA_HOST_COMPILER` | `CMAKE_HG_HOST_COMPILER` | 宿主编译器 |
| `CUDAFLAGS`(环境变量) | `HGFLAGS`(环境变量) | 环境变量 |
| `CUDA_SEPARABLE_COMPILATION` | → `hgcc_enable_rdc(target)` | 分离编译 |

**Imported target 替换表**:

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

### 第 4 步:目标架构

PPU 架构通过 `CMAKE_HG_ARCHITECTURES` 指定,可用值:

| 架构 | 说明 |
|------|-------------|
| `ppu_10` | PPU 1.0 |
| `ppu_15` | PPU 1.5 |
| `vm_10` | VM 1.0(仿真) |
| `vm_15` | VM 1.5(仿真) |
| `all` | 所有架构 |
| `all-ppu` | 所有 PPU 物理架构 |
| `all-vm` | 所有 VM 仿真架构 |

```cmake
# 单个架构
set(CMAKE_HG_ARCHITECTURES ppu_15)

# 多个架构
set(CMAKE_HG_ARCHITECTURES ppu_10 ppu_15)

# 所有架构
set(CMAKE_HG_ARCHITECTURES all)
```

不指定时,hgcc 使用默认架构。可通过 `hgcc --list-gpu-arch` 查询当前 SDK 支持的架构列表。

### 第 5 步:分离编译(RDC)

```cmake
# CUDA
add_executable(myapp a.cu b.cu main.cpp)
set_target_properties(myapp PROPERTIES CUDA_SEPARABLE_COMPILATION ON)

# HGGC
add_executable(myapp a.hg b.hg main.cpp)
hgcc_enable_rdc(myapp)
```

### 完整迁移示例

```cmake
# ============== CUDA 原始项目 ==============
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
# ============== HGGC 迁移后 ==============
cmake_minimum_required(VERSION 3.20)
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")

set(CMAKE_HG_ENABLE_CU_EXTENSION ON)  # 保留 .cu 源文件,无需改名

project(matmul LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)

set(CMAKE_HG_STANDARD 17)
set(CMAKE_HG_ARCHITECTURES ppu_15)

add_executable(matmul
  matmul_kernel.cu        # .cu 文件无需改名
  matmul_host.cpp
  main.cpp)

target_link_libraries(matmul PRIVATE
  HGGC::acblas
  HGGC::toolkit)

hgcc_enable_rdc(matmul)
```

### 注意事项

- `.cpp` 文件中 `#include` SDK 头文件时,需链接 `HGGC::toolkit` 以获取头文件路径
  (CUDA 中由 CMake 隐式处理;HGGC 需显式声明)。
- kernel 语法(`__global__`、`<<<>>>`、`dim3` 等)完全兼容,无需修改。
- Runtime/Driver API 调用需替换——详见 HGGC 编程指南。

## 自动化迁移工具

`scripts/cuda_to_hgcc.sh` 脚本可批量替换 CMakeLists.txt 中的 CUDA 变量名和 target 名:

```bash
# 预览变更(不修改文件)
bash scripts/cuda_to_hgcc.sh /path/to/cuda-project

# 应用变更(原文件备份为 *.cuda_bak)
bash scripts/cuda_to_hgcc.sh /path/to/cuda-project --apply
```

脚本自动完成 CMakeLists.txt / *.cmake 文件中的名称替换。以下 CMake 层面的步骤仍需人工确认:

1. **架构值**:替换为 PPU 目标架构(参见上方架构表)。
2. **MODULE_PATH**:`source cmake-hgcc/envsetup.sh` 或在 CMakeLists.txt 中设置。
3. **RDC**:将 `CUDA_SEPARABLE_COMPILATION` 属性改为 `hgcc_enable_rdc(target)` 调用。
4. **混合源 target**:为含 `.cpp` 的 target 添加 `target_link_libraries(... HGGC::toolkit)`。
5. **`include(HGGCUtilities)`**:使用 RDC 或 fatbin 函数时需添加。

源文件内容的修改(API 替换、头文件替换等)请参考 HGGC 编程指南。

## 附录:从 hgcc `add_custom_command` 写法迁移

使用 `project(xxx NONE)` + `add_custom_command` 手动调用 hgcc 的项目,也应迁移到
cmake-hgcc。典型变化:

```cmake
# 迁移前(project NONE + custom command,每个 target 约 19 行):
project(vectorAdd_hgcc NONE)
set(SRC vectorAdd.hg)
set(OUT ${CMAKE_CURRENT_BINARY_DIR}/vectorAdd.out)
add_custom_command(OUTPUT ${OUT}
    COMMAND hgcc -x hg ${SRC} -I ${COMMON_DIR} -o ${OUT}
    DEPENDS ${SRC})
add_custom_target(vectorAdd ALL DEPENDS ${OUT})

# 迁移后(标准 CMake,3 行):
project(vectorAdd LANGUAGES HG)
add_executable(vectorAdd vectorAdd.hg)
target_include_directories(vectorAdd PRIVATE ${COMMON_DIR})
```

**链接 SDK 库**(如 hgrtc、acblas):
```cmake
target_link_libraries(myapp PRIVATE HGGC::hgrtc HGGC::acblas)
```

**foreach 批量测试**:
```cmake
foreach(_test test_a test_b test_c)
  add_executable(${_test} ${_test}.hg)
  target_include_directories(${_test} PRIVATE ${COMMON_DIR})
endforeach()
```

**Fatbin 生成**:
```cmake
hgcc_add_fatbin(my_kernel kernel.hg INCLUDE_DIRECTORIES ${COMMON_DIR})
```

**自动化工具**:`python3 scripts/migrate_cmake.py /path/to/project` 可自动完成上述
`add_custom_command` → cmake-hgcc 迁移(原文件备份为 `.bak`)。

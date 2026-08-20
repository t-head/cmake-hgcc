# cmake-hgcc

通过 hgcc 编译器为 HGGC 提供 CMake 语言支持,带来与 CMake 内置语言支持一致的原生 CMake 体验。

> [English](README.md)

## 目录

- [术语](#术语)
- [快速开始](#快速开始)
- [CUDA 迁移](#cuda-迁移)
- [变量参考](#变量参考)
- [Imported Targets](#imported-targets)
- [工具函数](#工具函数)
- [测试](#测试)
- [故障排查](#故障排查)
- [依赖要求](#依赖要求)
- [许可证](#许可证)

## 术语

**HGGC** 与 **hgcc** 相关但含义不同:

- **HGGC**(HeteroGeneous General-purpose Computing)——面向异构计算系统的并行编程模型与语言。
- **hgcc**——HGGC C/C++ 编译器,用于构建 HGGC 程序。

## 快速开始

cmake-hgcc 在 `cmake/Modules` 下提供了一组 CMake 语言模块。让 CMake 找到这些模块后,
即可像使用内置语言一样使用 `HG`。

**1. 注册模块。** source 自带的辅助脚本,或手动将 `CMAKE_MODULE_PATH` 指向模块目录:

```bash
# 将 CMAKE_MODULE_PATH(以及 CMAKE_PREFIX_PATH)设置为自带模块目录
source /path/to/cmake-hgcc/envsetup.sh
```

```cmake
# ……或者不使用 envsetup.sh,手动添加模块目录:
list(APPEND CMAKE_MODULE_PATH "/path/to/cmake-hgcc/cmake/Modules")
```

> `envsetup.sh` 是 cmake-hgcc 自带的辅助脚本——它只负责注册 CMake 模块。
> `hgcc` 编译器本身必须已可通过 `PATH`、`HGCC` 变量或 `PPU_SDK` 找到
> (参见[依赖要求](#依赖要求))。

**2. 编写一个最小的 `CMakeLists.txt`:**

```cmake
cmake_minimum_required(VERSION 3.20)

project(myapp LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)

add_executable(myapp main.hg helper.cpp)
target_link_libraries(myapp PRIVATE HGGC::toolkit)
```

**3. 构建并测试:**

```bash
cmake -B build
cmake --build build
ctest --test-dir build
```

## CUDA 迁移

对于已有 CUDA CMake 项目的用户,cmake-hgcc 提供了一条迁移路径,方便向 HGGC 过渡。
由于遵循标准 CMake 惯例,大多数项目只需少量修改即可完成切换。

CUDA→HGGC 变量/target 映射、逐步迁移示例及自动化迁移工具,
详见[迁移指南](docs/MIGRATION.zh-CN.md)。

## 变量参考

### 编译器

| 变量 | 说明 | 示例 |
|----------|-------------|---------|
| `CMAKE_HG_COMPILER` | hgcc 路径 | `/usr/local/PPU_SDK/bin/hgcc` |
| `CMAKE_HG_COMPILER_VERSION` | 编译器版本 | `2.1.1` |
| `CMAKE_HG_HOST_COMPILER` | 宿主 C++ 编译器 | `/usr/bin/g++` |
| `CMAKE_HG_HOST_LINK_LAUNCHER` | 宿主链接器 | `/usr/bin/g++` |
| `CMAKE_HG_ARCHITECTURES` | 目标 GPU 架构 | `ppu_10;ppu_15` |
| `CMAKE_HG_STANDARD` | HG 源文件的 C++ 标准 | `17` |
| `CMAKE_HG_STANDARD_REQUIRED` | `CMAKE_HG_STANDARD` 不支持时报错 | `ON` |
| `CMAKE_HG_EXTENSIONS` | 使用 C++ 标准的编译器扩展变体(需在 `project()`/`enable_language(HG)` 之前设置) | `ON` |
| `CMAKE_HG_SEPARABLE_COMPILATION` | 为所有 HG 目标开启 RDC(需在 `project()`/`enable_language(HG)` 之前设置);混合 HG+CXX 目标还需 `LINKER_LANGUAGE HG` | `OFF` |
| `CMAKE_HG_FLAGS` | 全局编译选项 | |
| `CMAKE_HG_FLAGS_DEBUG` | Debug 选项 | `-g -G` |
| `CMAKE_HG_FLAGS_RELEASE` | Release 选项 | `-O3 -DNDEBUG` |
| `CMAKE_HG_COMPILER_LAUNCHER` | 编译缓存(ccache/sccache) | `ccache` |
| `CMAKE_HG_RUNTIME_LIBRARY` | 运行时链接方式(`SHARED` / `NONE`) | `SHARED` |
| `CMAKE_HG_ENABLE_CU_EXTENSION` | 将 `.cu` 文件视为 HG 源文件 | `OFF` |
| `CMAKE_HG_COMPILER_FORCED` | 跳过编译器健全性测试 | `TRUE` |

### 环境变量

| 变量 | 说明 |
|----------|-------------|
| `HGCC` | hgcc 编译器路径 |
| `HGCCHOSTCXX` | 宿主 C++ 编译器 |
| `HGFLAGS` | 默认编译选项 |
| `PPU_SDK` | SDK 根目录 |
| `CMAKE_HG_COMPILER_LAUNCHER` | 编译器启动器——当同名 CMake 变量未设置时,用该环境变量初始化它 |

### Toolkit(`find_package(HGGCToolkit)`)

| 变量 | 说明 |
|----------|-------------|
| `HGGCToolkit_FOUND` | 是否找到 SDK |
| `HGGCToolkit_VERSION` | SDK 版本 |
| `HGGCToolkit_ROOT` | SDK 根目录 |
| `HGGCToolkit_INCLUDE_DIR` | 头文件目录 |
| `HGGCToolkit_LIBRARY_DIR` | 库目录 |
| `HGGCToolkit_BIN_DIR` | 二进制目录 |

SDK 根目录搜索顺序:`HGGCToolkit_ROOT`(CMake 变量或环境变量——同时作为结果变量输出)、
`CMAKE_HG_TOOLKIT_ROOT`(启用 HG 语言时由编译器路径推导,可覆盖)、`PPU_SDK` 环境变量,
最后是 `/usr/local/PPU_SDK`。

## Imported Targets

| Target | 库 | 用途 |
|--------|---------|---------|
| `HGGC::toolkit` | (interface) | 聚合 target——链接运行时库 + 头文件路径 |
| `HGGC::hggcrt` | libhggcrt1.so | GPU 运行时 |
| `HGGC::hggc` | libhggc.so | 驱动库 |
| `HGGC::hgrtc` | libhgrtc.so | 运行时编译 |
| `HGGC::hgrtc_builtins` | libhgrtc_builtins.so | 运行时编译内置函数 |
| `HGGC::hgvm` | libhgvm.so | VM API |
| `HGGC::hgJitLink` | libhgJitLink.so | JIT 链接器 |
| `HGGC::hgJitLink_static` | libhgJitLink_static.a | JIT 链接器(静态) |
| `HGGC::acblas` | libacblas.so | BLAS |
| `HGGC::acblasLt` | libacblasLt.so | BLAS(轻量版) |
| `HGGC::acfft` | libacfft.so | FFT |
| `HGGC::acrand` | libacrand.so | 随机数 |
| `HGGC::acdnn` | libacdnn.so | DNN |
| `HGGC::acsparse` | libacsparse.so | 稀疏矩阵 |
| `HGGC::acsolver` | libacsolver.so | 线性方程求解 |
| `HGGC::hgjpeg` | libhgjpeg.so | JPEG 编解码 |
| `HGGC::pccl` | libpccl.so | 集合通信 |

## 工具函数

以下辅助函数由 `include(HGGCUtilities)` 提供:

```cmake
# RDC(分离编译)
add_executable(myapp a.hg b.hg host.cpp)
hgcc_enable_rdc(myapp)

# 与上面等价;混合 HG+CXX 目标需设置 LINKER_LANGUAGE HG
# 以便 hgcc 执行设备链接:
set_target_properties(myapp PROPERTIES
  HG_SEPARABLE_COMPILATION ON
  LINKER_LANGUAGE HG)

# 或为所有 HG 目标全局开启——必须在
# project()/enable_language(HG) 之前设置:
#   set(CMAKE_HG_SEPARABLE_COMPILATION ON)

# 或使用快捷方式:
hgcc_add_rdc_executable(myapp a.hg b.hg host.cpp)
hgcc_add_rdc_library(mylib STATIC a.hg b.hg)

# Fatbin 生成
hgcc_add_fatbin(my_kernel kernel.hg
  ARCHITECTURES ppu_15
  INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/include
  DEPENDS some_generated_header.h)

# 将 fatbin 转换为 C 头文件
hgcc_fatbin_to_header(${my_kernel_OUTPUT} kernel_fatbin.h)

# 为特定 target 的 HG 源文件设置 C++ 标准
hgcc_set_standard(myapp 17)
```

## 测试

`test/` 目录包含一套 CTest 测试,覆盖单个 `.hg`、`.hg` + `.cpp` 混合源、fatbin 生成、
RDC(纯 HG、混合源及 `hgcc_enable_rdc` 方式)、`.cu` 兼容性和共享库。

```bash
bash scripts/run_tests.sh                              # hgcc 在 PATH 中
DOCKER_CONTAINER=my_dev bash scripts/run_tests.sh      # 在容器内运行
```

测试脚本会分别用 `Unix Makefiles` 和 `Ninja`(可用时)配置、构建,然后运行 `ctest`。

## 故障排查

**"Could not find hgcc compiler"**
- `source $PPU_SDK/envsetup.sh` 或 `-DCMAKE_HG_COMPILER=/path/to/hgcc`

**".cpp files can't find hggc_runtime.h"**
- `target_link_libraries(target PRIVATE HGGC::toolkit)`

**HG+CXX 混合 target 出现 "Undefined reference to hggcMalloc"**
- 非 RDC:应自动解决(隐式链接库)。检查 `CMAKE_HG_IMPLICIT_LINK_LIBRARIES`
- RDC:使用 `hgcc_enable_rdc(target)`

**"CMAKE_HG_STANDARD=XX is not supported"**
- 支持的值:11、14、17、20

## 依赖要求

- CMake >= 3.20
- hgcc(PPU SDK)
- Linux(x86_64 或 aarch64)

## 许可证

cmake-hgcc 为 HGGC 编译器提供 CMake 语言支持,由平头哥(上海)半导体有限公司开发,
采用 Apache License, Version 2.0 许可。

详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE) 文件。

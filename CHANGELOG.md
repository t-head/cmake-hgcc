# Changelog

## 1.0.0 (2026-06-09)

### Features
- CMake custom language support for HG (.hg files) via `enable_language(HG)` / `project(... LANGUAGES HG)`
- Compiler detection with version extraction and host compiler auto-discovery
- Implicit link information extraction from hgcc verbose linker output
- `FindHGGCToolkit.cmake` with up to 16 library imported targets (created per discovered library; standalone or with `enable_language(HG)`)
- `HGGC::toolkit` umbrella target for easy include/link setup (aggregates the core `hggcrt` and `hggc` runtime libraries)
- RDC (separable compilation) support via `hgcc_enable_rdc()` / `hgcc_add_rdc_executable()`, plus the `HG_SEPARABLE_COMPILATION` target property and `CMAKE_HG_SEPARABLE_COMPILATION` variable
- Fatbin generation via `hgcc_add_fatbin()`
- C++ standard support (`CMAKE_HG_STANDARD`, `CMAKE_HG_EXTENSIONS`, `hgcc_set_standard()`)
- `CMAKE_HG_RUNTIME_LIBRARY` (SHARED / NONE)
- `CMAKE_HG_STANDARD_REQUIRED` enforcement
- `CMAKE_HG_ENABLE_CU_EXTENSION` opt-in .cu file support for CUDA migration
- PIC/PIE, RPATH, SONAME, shared library support
- Build-type flags (Debug/Release/RelWithDebInfo/MinSizeRel)
- Architecture selection via `CMAKE_HG_ARCHITECTURES`
- Dependency file generation for incremental builds
- Compiler launcher support (ccache/sccache) via `CMAKE_HG_COMPILER_LAUNCHER`
- `-forward-unknown-to-host-compiler` enabled by default
- `-Xcompiler=` / `-Xlinker=` wrapper flag support
- IPO/LTO variables (`-dlto` at compile and device-link stages; requires an HG-aware CMake — with stock CMake, pass `-dlto` via `CMAKE_HG_FLAGS`)
- Warning as error (`-Werror all-warnings`)
- Response file support (`--options-file`)
- Device link rules (`CMAKE_HG_DEVICE_LINK_LIBRARY` / `EXECUTABLE`)
- CMake config package for `find_package(cmake-hgcc CONFIG)`
- CMakePresets.json template
- `envsetup.sh` for shell environment setup
- CTest integration (8 test cases; the `cu_compat` case runs only with `-DCMAKE_HG_ENABLE_CU_EXTENSION=ON`, 7 by default)
- Unix Makefiles and Ninja generator support
- CUDA→HGGC migration script (`scripts/cuda_to_hgcc.sh`)
- Legacy migration script (`scripts/migrate_cmake.py`)
- Migration examples from hggc-samples (5 patterns)

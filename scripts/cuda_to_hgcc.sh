#!/bin/bash
# Semi-automated CUDA → HGGC CMakeLists.txt migration helper.
#
# Performs text replacements in CMakeLists.txt files for the common CUDA→HGGC
# mappings. Source files (.cu→.hg) and API calls (cuda*→hggc*) still need
# manual review.
#
# Usage:
#   bash cuda_to_hgcc.sh /path/to/project              # dry-run (shows diff)
#   bash cuda_to_hgcc.sh /path/to/project --apply       # apply changes
#
# Always review the output before applying.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <project-dir> [--apply]"
    echo ""
    echo "Replaces CUDA CMake variable/target names with the corresponding HGGC names."
    echo "Run without --apply first to preview changes."
    exit 1
fi

PROJECT_DIR="$1"
APPLY="${2:-}"

# CMake variable and target replacements
declare -A REPLACEMENTS=(
    # Language
    ["LANGUAGES CXX CUDA"]="LANGUAGES CXX HG"
    ["LANGUAGES CUDA CXX"]="LANGUAGES CXX HG"
    ["LANGUAGES CUDA"]="LANGUAGES HG"
    ["enable_language(CUDA)"]="enable_language(HG)"

    # find_package
    ["find_package(CUDAToolkit"]="find_package(HGGCToolkit"
    ["FindCUDAToolkit"]="FindHGGCToolkit"

    # Variables
    ["CMAKE_CUDA_COMPILER"]="CMAKE_HG_COMPILER"
    ["CMAKE_CUDA_ARCHITECTURES"]="CMAKE_HG_ARCHITECTURES"
    ["CMAKE_CUDA_STANDARD"]="CMAKE_HG_STANDARD"
    ["CMAKE_CUDA_STANDARD_REQUIRED"]="CMAKE_HG_STANDARD_REQUIRED"
    ["CMAKE_CUDA_FLAGS"]="CMAKE_HG_FLAGS"
    ["CMAKE_CUDA_HOST_COMPILER"]="CMAKE_HG_HOST_COMPILER"
    ["CMAKE_CUDA_RUNTIME_LIBRARY"]="CMAKE_HG_RUNTIME_LIBRARY"
    ["CMAKE_CUDA_COMPILER_LAUNCHER"]="CMAKE_HG_COMPILER_LAUNCHER"
    ["CUDAFLAGS"]="HGFLAGS"

    # Imported targets
    ["CUDA::toolkit"]="HGGC::toolkit"
    ["CUDA::cudart_static"]="HGGC::hggcrt"
    ["CUDA::cudart"]="HGGC::hggcrt"
    ["CUDA::cuda_driver"]="HGGC::hggc"
    ["CUDA::nvrtc"]="HGGC::hgrtc"
    ["CUDA::nvrtc_static"]="HGGC::hgrtc"
    ["CUDA::cublas"]="HGGC::acblas"
    ["CUDA::cublasLt"]="HGGC::acblasLt"
    ["CUDA::cufft"]="HGGC::acfft"
    ["CUDA::curand"]="HGGC::acrand"
    ["CUDA::cusparse"]="HGGC::acsparse"
    ["CUDA::cusolver"]="HGGC::acsolver"
    ["CUDA::cudnn"]="HGGC::acdnn"
    ["CUDA::nccl"]="HGGC::pccl"
    ["CUDA::nvJitLink"]="HGGC::hgJitLink"

    # Properties
    ["CUDA_SEPARABLE_COMPILATION ON"]="HG_SEPARABLE_COMPILATION ON"
    ["CUDA_SEPARABLE_COMPILATION TRUE"]="HG_SEPARABLE_COMPILATION ON"
)

find_cmake_files() {
    find "$PROJECT_DIR" -name "CMakeLists.txt" -o -name "*.cmake" | grep -v build | sort
}

FILES=$(find_cmake_files)
if [[ -z "$FILES" ]]; then
    echo "No CMakeLists.txt or *.cmake files found in $PROJECT_DIR"
    exit 1
fi

echo "=== CUDA → HGGC CMake Migration ==="
echo "Project: $PROJECT_DIR"
echo "Files:   $(echo "$FILES" | wc -l)"
echo ""

BUILD_SED_CMD=""
for from in "${!REPLACEMENTS[@]}"; do
    to="${REPLACEMENTS[$from]}"
    # Escape special chars for sed
    from_esc=$(printf '%s' "$from" | sed 's/[[\.*^$()+?{|]/\\&/g')
    to_esc=$(printf '%s' "$to" | sed 's/[&/\]/\\&/g')
    BUILD_SED_CMD="${BUILD_SED_CMD}s|${from_esc}|${to_esc}|g;"
done

if [[ "$APPLY" == "--apply" ]]; then
    for f in $FILES; do
        cp "$f" "${f}.cuda_bak"
        sed -i "${BUILD_SED_CMD}" "$f"
    done
    echo "Applied replacements. Originals saved as *.cuda_bak"
    echo ""
    echo "IMPORTANT: Still need manual work:"
    echo "  1. Rename .cu source files to .hg"
    echo "  2. Replace cuda* API calls with hggc* in source files"
    echo "  3. Update architecture values (e.g. 70 → ppu_15)"
    echo "  4. Add 'list(APPEND CMAKE_MODULE_PATH ...)' or 'source envsetup.sh'"
    echo "  5. RDC: CUDA_SEPARABLE_COMPILATION was renamed to HG_SEPARABLE_COMPILATION;"
    echo "     mixed .hg+.cpp targets also need LINKER_LANGUAGE HG"
    echo "     (hgcc_enable_rdc(target) sets both)"
    echo "  6. Add 'include(HGGCUtilities)' if using RDC or fatbin functions"
    echo "  7. Review and test"
else
    echo "=== Preview (dry-run) ==="
    for f in $FILES; do
        result=$(sed "${BUILD_SED_CMD}" "$f")
        diff_output=$(diff "$f" <(echo "$result") || true)
        if [[ -n "$diff_output" ]]; then
            echo "--- $(realpath --relative-to="$PROJECT_DIR" "$f") ---"
            echo "$diff_output"
            echo ""
        fi
    done
    echo "Run with --apply to make changes."
fi

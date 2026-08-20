#!/bin/bash
# Automated test runner for cmake-hgcc.
#
# Usage:
#   bash scripts/run_tests.sh                                    # run directly (must have hgcc in PATH)
#   DOCKER_CONTAINER=my_dev bash scripts/run_tests.sh            # run via Docker
#   bash scripts/run_tests.sh --inside-docker                    # already inside Docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE_DIR="${PROJECT_DIR}/cmake/Modules"

if [[ "${1:-}" != "--inside-docker" ]] && [[ -n "${DOCKER_CONTAINER:-}" ]]; then
    echo "=== Running tests in Docker container: ${DOCKER_CONTAINER} ==="
    docker exec "${DOCKER_CONTAINER}" bash "${BASH_SOURCE[0]}" --inside-docker
    exit $?
fi

PASS=0
FAIL=0
ERRORS=""

run_test_suite() {
    local name="$1" dir="$2" generator="${3:-Unix Makefiles}"
    local build_dir="${dir}/build_${name}"

    echo ""
    echo "========================================"
    echo " Test Suite: ${name} (${generator})"
    echo "========================================"

    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"

    echo "[configure]"
    if ! cmake -G "${generator}" \
        -DCMAKE_MODULE_PATH="${MODULE_DIR}" \
        -S "${dir}" -B "${build_dir}" 2>&1; then
        echo "FAIL: configure failed"
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${name}: configure failed"
        return 1
    fi

    echo "[build]"
    if ! cmake --build "${build_dir}" -j "$(nproc)" 2>&1; then
        echo "FAIL: build failed"
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${name}: build failed"
        return 1
    fi

    echo "[test]"
    if cd "${build_dir}" && ctest --output-on-failure 2>&1; then
        echo "PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${name}"
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${name}: ctest failed"
    fi

    cd "${PROJECT_DIR}"
    rm -rf "${build_dir}"
}

# Test suite with Unix Makefiles
run_test_suite "unit-make" "${PROJECT_DIR}/test" "Unix Makefiles"

# Test suite with Ninja
if command -v ninja &>/dev/null; then
    run_test_suite "unit-ninja" "${PROJECT_DIR}/test" "Ninja"
fi

# Migration examples
if [[ -d "${PROJECT_DIR}/../../hggc-samples" ]]; then
    run_test_suite "examples-make" "${PROJECT_DIR}/examples" "Unix Makefiles"
fi

echo ""
echo "========================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
if [[ ${FAIL} -gt 0 ]]; then
    echo -e "Failures:${ERRORS}"
    exit 1
fi
echo "All tests passed."

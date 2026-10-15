#!/bin/bash
# Runs the device cases of Full CI's build trees on a PPU.
#
# GitHub-hosted runners have no PPU, so the Full CI job in workflows/ci.yml
# builds everything but runs only the cases that need no device. It packs its
# four build trees into one archive, and the ppu-test job runs this script on
# an 810E through t-head/ppu-scheduler-action. The PPU pool takes no build
# work: nothing is compiled here, the image only provides the PPU SDK runtime.
#
# The cases are the binaries ctest would run on a device: every test/ case but
# fatbin_exists, which Full CI already runs, and the TEST_COMMAND of every
# NEEDS_DEVICE case in feature_tests/CMakeLists.txt. Keep the lists in sync.
#
# Usage: run_device_tests.sh <device-tests.tar.gz>
set -uo pipefail

archive="${1:-}"
if [[ ! -f "${archive}" ]]; then
  echo "usage: $0 <device-tests.tar.gz>" >&2
  exit 2
fi

root="$(mktemp -d)"
trap 'rm -rf "${root}"' EXIT
if ! tar -xzf "${archive}" -C "${root}"; then
  echo "cannot unpack ${archive}" >&2
  exit 1
fi

# envsetup.sh belongs to the SDK and is not written for nounset
sdk_env="${PPU_SDK:-/usr/local/PPU_SDK}/envsetup.sh"
if [[ -f "${sdk_env}" ]]; then
  set +u
  source "${sdk_env}"
  set -u
else
  echo "warning: ${sdk_env} not found, running with the image environment as is" >&2
fi

echo "node: ${NODE_NAME:-unknown}"
ppu-smi || echo "warning: ppu-smi failed" >&2

cases=()
for tree in unit-make unit-ninja; do
  for bin in test_simple test_mixed test_rdc_pure test_rdc_mixed test_rdc_enable \
             test_shared_user; do
    cases+=("${tree}/${bin}")
  done
done
# Only the Ninja build turns the .cu extension on
cases+=(unit-ninja/test_cu_compat)
for tree in features-make features-ninja; do
  cases+=("${tree}/set_standard/probe_cxx14"
          "${tree}/rdc_library/test_rdc_lib_user"
          "${tree}/runtime_library_none/test_runtime_none"
          "${tree}/compiler_launcher/test_launcher_probe")
done

failed=()
for test_case in "${cases[@]}"; do
  bin="${root}/${test_case}"
  dir="$(dirname "${bin}")"
  echo ""
  echo "=== ${test_case}"
  if [[ ! -x "${bin}" ]]; then
    echo "--- FAILED: no executable at this path in ${archive}"
    failed+=("${test_case}: missing")
    continue
  fi
  # Run in the build directory, as ctest does. BUILD_RPATH still points into
  # the hosted runner's build tree, so the binary's own directory goes on the
  # library path for test_shared_user's libtest_shlib.so.
  lib_path="${dir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  output="$(cd "${dir}" && LD_LIBRARY_PATH="${lib_path}" timeout -k 10 120 "${bin}" 2>&1)"
  rc=$?
  printf '%s\n' "${output}"
  # test/'s binaries exit with their error count, which wraps modulo 256, so a
  # FAILED verdict in the output fails the case too.
  if [[ ${rc} -ne 0 ]]; then
    # timeout exits with 124 when the case hangs
    echo "--- FAILED: exit ${rc}"
    failed+=("${test_case}: exit ${rc}")
    LD_LIBRARY_PATH="${lib_path}" ldd "${bin}" || true
  elif grep -qw FAILED <<<"${output}"; then
    echo "--- FAILED: printed FAILED"
    failed+=("${test_case}: printed FAILED")
  else
    echo "--- passed"
  fi
done

echo ""
echo "${#cases[@]} device cases, ${#failed[@]} failed"
if [[ ${#failed[@]} -gt 0 ]]; then
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

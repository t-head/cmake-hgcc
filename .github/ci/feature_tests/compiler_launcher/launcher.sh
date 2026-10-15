#!/bin/sh
# Fake compiler launcher used by the compiler_launcher case.
#
# Behaves like ccache/sccache: first argument is the real compiler, the rest are
# its arguments. It marks the compilation by defining HGGC_LAUNCHER_ACTIVE so the
# probe source can prove — at compile time — that CMAKE_HG_COMPILER_LAUNCHER
# really was prepended to the HG compile rule.

if [ $# -lt 1 ]; then
  echo "launcher.sh: no compiler given" >&2
  exit 1
fi

prog="$1"
shift

exec "$prog" -DHGGC_LAUNCHER_ACTIVE=1 "$@"

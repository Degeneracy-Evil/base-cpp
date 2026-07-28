#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TEST_ROOT/utils/lib" "$TEST_ROOT/bin" "$TEST_ROOT/include" \
    "$TEST_ROOT/src" "$TEST_ROOT/tests/unit"
cp "$PROJECT_ROOT/utils/check.sh" "$TEST_ROOT/utils/check.sh"
cp "$PROJECT_ROOT/utils/fix.sh" "$TEST_ROOT/utils/fix.sh"
cp "$PROJECT_ROOT/utils/lib/quality_common.sh" "$TEST_ROOT/utils/lib/quality_common.sh"

printf '%s\n' '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'for arg in "$@"; do' \
    '    case "$arg" in --dry-run|--Werror) continue ;; esac' \
    '    [ -f "$arg" ] || continue' \
    '    echo "$arg" >> "${QUALITY_TEST_FORMAT_LOG:?}"' \
    '    if [[ " $* " == *" -i "* ]]; then' \
    "        perl -pi -e 's/BAD_FORMAT/GOOD_FORMAT/g' \"\$arg\"" \
    '    elif grep -q BAD_FORMAT "$arg"; then' \
    '        exit 1' \
    '    fi' \
    'done' > "$TEST_ROOT/bin/clang-format"

printf '%s\n' '#!/usr/bin/env bash' \
    'printf "%s\\n" "$*" >> "${QUALITY_TEST_TIDY_LOG:?}"' \
    'exit 0' > "$TEST_ROOT/bin/clang-tidy"

printf '%s\n' '#!/usr/bin/env bash' \
    'if [ "${1:-}" = project ]; then' \
    '    mkdir -p build' \
    '    printf "[]\\n" > build/compile_commands.json' \
    'fi' \
    'exit 0' > "$TEST_ROOT/bin/xmake"

chmod +x "$TEST_ROOT/bin/clang-format" "$TEST_ROOT/bin/clang-tidy" "$TEST_ROOT/bin/xmake"

cd "$TEST_ROOT"
git init -q
git config user.name "Quality Script Test"
git config user.email "quality@example.invalid"
git config commit.gpgsign false
printf 'BasedOnStyle: LLVM\n' > .clang-format
printf 'Checks: bugprone-*\n' > .clang-tidy
printf 'set_languages("c++20")\n' > xmake.lua
printf '#pragma once\n' > include/example.hpp
printf 'int main() { return 0; }\n' > src/main.cpp
printf 'int other() { return 1; }\n' > src/other.cpp
printf 'int test_example() { return 0; }\n' > tests/unit/test_example.cpp
git add .
git commit -qm "fixture"

export PATH="$TEST_ROOT/bin:$PATH"
export QUALITY_TEST_FORMAT_LOG="$TEST_ROOT/format.log"
export QUALITY_TEST_TIDY_LOG="$TEST_ROOT/tidy.log"
: > "$QUALITY_TEST_FORMAT_LOG"
: > "$QUALITY_TEST_TIDY_LOG"

# 未跟踪、带空格文件：check 只读失败，fix 修复且不自动暂存。
printf 'int BAD_FORMAT = 0;   \n' > "src/new file.cpp"
before_hash="$(git hash-object "src/new file.cpp")"
if utils/check.sh --skip-tidy --skip-build --skip-test > check.log 2>&1; then
    fail "check unexpectedly accepted invalid untracked source"
fi
after_hash="$(git hash-object "src/new file.cpp")"
[ "$before_hash" = "$after_hash" ] || fail "check modified a source file"
grep -q 'Run: utils/fix.sh' check.log || fail "check did not suggest fix.sh"
utils/fix.sh >/dev/null
grep -q GOOD_FORMAT "src/new file.cpp" || fail "fix did not run clang-format"
if LC_ALL=C grep -qE '[[:blank:]]+$' "src/new file.cpp"; then
    fail "fix did not remove trailing whitespace"
fi
git diff --cached --quiet || fail "fix staged files"

# 暂存检查和部分暂存拒绝。
git add "src/new file.cpp"
utils/check.sh --staged --skip-tidy >/dev/null
printf '// unstaged\n' >> "src/new file.cpp"
if utils/check.sh --staged --skip-tidy > partial.log 2>&1; then
    fail "staged mode accepted a partially staged file"
fi
grep -q 'staged and unstaged' partial.log || fail "partial staging error is unclear"
git restore "src/new file.cpp"
git commit -qm "add spaced source"

# .clang-format 变化必须扩大到全部源码。
: > "$QUALITY_TEST_FORMAT_LOG"
printf 'BasedOnStyle: LLVM\nColumnLimit: 100\n' > .clang-format
utils/check.sh --skip-tidy --skip-build --skip-test >/dev/null
grep -q '^src/other.cpp$' "$QUALITY_TEST_FORMAT_LOG" || \
    fail ".clang-format change did not trigger full format"
git restore .clang-format

# 公共头文件变化必须对所有编译单元运行 tidy。
: > "$QUALITY_TEST_TIDY_LOG"
printf '#pragma once\n// changed\n' > include/example.hpp
utils/check.sh --skip-build --skip-test >/dev/null
grep -q 'src/other.cpp' "$QUALITY_TEST_TIDY_LOG" || \
    fail "header change did not trigger full tidy"
grep -q 'tests/unit/test_example.cpp' "$QUALITY_TEST_TIDY_LOG" || \
    fail "test sources were omitted from full tidy"

echo "Quality script integration tests passed."

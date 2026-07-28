#!/usr/bin/env bash
# 只读质量检查：默认智能增量，--staged 检查提交内容，--full 执行全量检查。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/quality_common.sh"

MODE=changed
SKIP_TIDY=false
SKIP_BUILD=false
SKIP_TEST=false

for arg in "$@"; do
    case "$arg" in
        --staged)
            [ "$MODE" = changed ] || die "only one of --staged and --full may be used"
            MODE=staged
            ;;
        --full)
            [ "$MODE" = changed ] || die "only one of --staged and --full may be used"
            MODE=full
            ;;
        --skip-tidy) SKIP_TIDY=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --skip-test) SKIP_TEST=true ;;
        *) die "unknown option: $arg" ;;
    esac
done

cd "$PROJECT_ROOT"

SELECTED_FILES=()
if [ "$MODE" = staged ]; then
    collect_staged_files SELECTED_FILES
    for file in "${SELECTED_FILES[@]}"; do
        if ! git diff --quiet -- "$file"; then
            die "$file has both staged and unstaged changes. Resolve the partial staging first."
        fi
    done
elif [ "$MODE" = changed ]; then
    collect_changed_files SELECTED_FILES
else
    collect_all_files SELECTED_FILES
fi

FORMAT_ALL=false
TIDY_ALL=false
if [ "$MODE" = full ]; then
    FORMAT_ALL=true
    TIDY_ALL=true
else
    for file in "${SELECTED_FILES[@]}"; do
        case "$file" in
            .clang-format) FORMAT_ALL=true ;;
            .clang-tidy|xmake.lua) TIDY_ALL=true ;;
        esac
        if is_header "$file"; then
            TIDY_ALL=true
        fi
    done
fi

FORMAT_FILES=()
TIDY_FILES=()
if [ "$FORMAT_ALL" = true ] || [ "$TIDY_ALL" = true ]; then
    ALL_FORMAT_FILES=()
    ALL_TIDY_FILES=()
    collect_all_format_files ALL_FORMAT_FILES
    collect_all_tidy_files ALL_TIDY_FILES
fi

if [ "$FORMAT_ALL" = true ]; then
    FORMAT_FILES=("${ALL_FORMAT_FILES[@]}")
else
    for file in "${SELECTED_FILES[@]}"; do
        if [ -f "$file" ] && is_project_source "$file"; then
            FORMAT_FILES+=("$file")
        fi
    done
fi

if [ "$TIDY_ALL" = true ]; then
    TIDY_FILES=("${ALL_TIDY_FILES[@]}")
else
    for file in "${SELECTED_FILES[@]}"; do
        if [ -f "$file" ] && is_source "$file"; then
            case "$file" in
                src/*|tests/*) TIDY_FILES+=("$file") ;;
            esac
        fi
    done
fi

TOTAL=0
FAILED=0
run_check() { TOTAL=$((TOTAL + 1)); info "$1"; }
mark_pass() { pass "$1"; }
mark_fail() { FAILED=$((FAILED + 1)); fail "$1"; }

# 1. whitespace / EOF
run_check "whitespace/eof"
WHITESPACE_FAILED=false
for file in "${SELECTED_FILES[@]}"; do
    is_text_file "$file" || continue
    if LC_ALL=C grep -nE '[[:blank:]]+$' "$file" >/dev/null; then
        echo "  trailing whitespace: $file"
        WHITESPACE_FAILED=true
    fi
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
        echo "  missing newline at EOF: $file"
        WHITESPACE_FAILED=true
    fi
done
if [ "$WHITESPACE_FAILED" = true ]; then
    mark_fail "whitespace/eof"
    if [ "$MODE" = full ]; then
        echo "  Run: utils/fix.sh --full"
    else
        echo "  Run: utils/fix.sh"
    fi
    [ "$MODE" != staged ] || echo "  Then review and stage the intended changes again."
    exit 1
fi
mark_pass "whitespace/eof"

# 2. clang-format
run_check "clang-format"
if [ "${#FORMAT_FILES[@]}" -eq 0 ]; then
    warn "clang-format (no matching source files)"
else
    need_cmd clang-format
    if clang-format --dry-run --Werror "${FORMAT_FILES[@]}"; then
        mark_pass "clang-format"
    else
        mark_fail "clang-format"
        if [ "$MODE" = full ]; then
            echo "  Run: utils/fix.sh --full"
        else
            echo "  Run: utils/fix.sh"
        fi
        [ "$MODE" != staged ] || echo "  Then review and stage the intended changes again."
        exit 1
    fi
fi

# 3. clang-tidy
if [ "$SKIP_TIDY" = false ]; then
    run_check "clang-tidy"
    if [ "${#TIDY_FILES[@]}" -eq 0 ]; then
        warn "clang-tidy (no matching source files)"
    else
        need_cmd clang-tidy
        need_cmd xmake
        if ! xmake project -k compile_commands build >/dev/null 2>&1; then
            mark_fail "clang-tidy (failed to generate compile_commands.json)"
            echo "  No automatic fix is available; inspect the xmake configuration."
            exit 1
        fi
        if [ ! -f "$PROJECT_ROOT/build/compile_commands.json" ]; then
            mark_fail "clang-tidy (compile_commands.json not found)"
            echo "  No automatic fix is available; inspect the xmake configuration."
            exit 1
        fi
        if clang-tidy -p="$PROJECT_ROOT/build" "${TIDY_FILES[@]}"; then
            mark_pass "clang-tidy"
        else
            mark_fail "clang-tidy"
            echo "  No automatic fix is available; review the diagnostics above."
            exit 1
        fi
    fi
else
    warn "clang-tidy (skipped)"
fi

# --staged is intentionally limited to the commit snapshot checks above.
if [ "$MODE" != staged ]; then
    if [ "$SKIP_BUILD" = false ]; then
        if [ "$MODE" = full ]; then
            BUILD_COMMAND=(xmake -r)
            BUILD_NAME="build (xmake -r)"
        else
            BUILD_COMMAND=(xmake build)
            BUILD_NAME="build (xmake build)"
        fi
        run_check "$BUILD_NAME"
        if "${BUILD_COMMAND[@]}" >/dev/null 2>&1; then
            mark_pass "$BUILD_NAME"
        else
            mark_fail "$BUILD_NAME"
            "${BUILD_COMMAND[@]}" 2>&1 | sed 's/^/  /' || true
            echo "  No automatic fix is available; review the build errors above."
            exit 1
        fi
    else
        warn "build (skipped)"
    fi

    if [ "$SKIP_TEST" = false ]; then
        run_check "tests"
        if xmake test; then
            mark_pass "tests"
        else
            mark_fail "tests"
            echo "  No automatic fix is available; review the test failures above."
            exit 1
        fi
    else
        warn "tests (skipped)"
    fi
fi

echo ""
echo "========================================"
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All $TOTAL checks passed.${RESET}"
else
    echo -e "${RED}$FAILED of $TOTAL checks failed.${RESET}"
fi
echo "========================================"

exit "$FAILED"

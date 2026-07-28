#!/usr/bin/env bash
# check.sh 与 fix.sh 的共享实现；不应被直接执行。

# ── 输出 ──────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "${GREEN}[PASS]${RESET} $1"; }
fail() { echo -e "${RED}[FAIL]${RESET} $1"; }
info() { echo -e "${BOLD}[....]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
die() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "$1 not found"; }

is_text_file() { [ -f "$1" ] && file --mime-type "$1" | grep -q ': text/'; }

# ── 文件类型判断 ──────────────────────────────────────────────

is_header() {
    case "$1" in
        *.h|*.hh|*.hpp|*.hxx) return 0 ;;
        *) return 1 ;;
    esac
}

is_source() {
    case "$1" in
        *.c|*.cc|*.cpp|*.cxx) return 0 ;;
        *) return 1 ;;
    esac
}

is_format_file() { is_header "$1" || is_source "$1"; }

is_project_source() {
    # 仅 include/、src/、tests/ 下的 C/C++ 头/源文件
    case "$1" in
        include/*|src/*|tests/*) is_format_file "$1" ;;
        *) return 1 ;;
    esac
}

# ── 文件收集 ──────────────────────────────────────────────────

collect_changed_files() {
    # 工作区变更（已暂存 + 未暂存 + 未跟踪）
    local -n result=$1
    mapfile -d '' result < <(
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            git diff HEAD --name-only -z --diff-filter=ACMR
        else
            git ls-files --cached -z
        fi
        git ls-files --others --exclude-standard -z
    )
}

collect_staged_files() {
    # 仅 git diff --cached（暂存区）
    local -n result=$1
    mapfile -d '' result < <(git diff --cached --name-only -z --diff-filter=ACMR)
}

collect_all_files() {
    # 全部已跟踪 + 未跟踪文件
    local -n result=$1
    mapfile -d '' result < <(git ls-files -co --exclude-standard -z)
}

collect_all_format_files() {
    # include/、src/、tests/ 下所有 C/C++ 头/源文件（clang-format）
    local -n result=$1
    result=()
    while IFS= read -r -d '' file; do
        result+=("$file")
    done < <(find include src tests -type f \
        \( -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \
        -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \) \
        -print0 2>/dev/null)
}

collect_all_tidy_files() {
    # src/、tests/ 下所有 C/C++ 源文件（clang-tidy；头文件通过编译单元间接检查）
    local -n result=$1
    result=()
    while IFS= read -r -d '' file; do
        result+=("$file")
    done < <(find src tests -type f \
        \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \) \
        -print0 2>/dev/null)
}

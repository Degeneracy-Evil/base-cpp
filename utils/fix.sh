#!/usr/bin/env bash
# 显式修复安全的机械问题：尾随空白、EOF 换行和 clang-format。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/quality_common.sh"

FULL_MODE=false
for arg in "$@"; do
    case "$arg" in
        --full) [ "$FULL_MODE" = false ] || die "--full specified more than once"; FULL_MODE=true ;;
        *) die "unknown option: $arg" ;;
    esac
done

cd "$PROJECT_ROOT"

FILES=()
if [ "$FULL_MODE" = true ]; then
    collect_all_files FILES
else
    collect_changed_files FILES
fi

FIXED=0
for file in "${FILES[@]}"; do
    is_text_file "$file" || continue
    before_hash="$(git hash-object "$file")"
    perl -pi -e 's/[ \t]+$//' "$file"
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
        printf '\n' >> "$file"
    fi
    after_hash="$(git hash-object "$file")"
    if [ "$before_hash" != "$after_hash" ]; then
        echo "whitespace/eof: $file"
        FIXED=$((FIXED + 1))
    fi
done

FORMAT_FILES=()
for file in "${FILES[@]}"; do
    if [ -f "$file" ] && is_project_source "$file"; then
        FORMAT_FILES+=("$file")
    fi
done

if [ "${#FORMAT_FILES[@]}" -gt 0 ]; then
    command -v clang-format >/dev/null 2>&1 || die "clang-format not found"
    for file in "${FORMAT_FILES[@]}"; do
        before_hash="$(git hash-object "$file")"
        clang-format -i "$file"
        after_hash="$(git hash-object "$file")"
        if [ "$before_hash" != "$after_hash" ]; then
            echo "clang-format: $file"
            FIXED=$((FIXED + 1))
        fi
    done
fi

echo "Applied $FIXED mechanical fix(es). Review the diff and stage changes manually."

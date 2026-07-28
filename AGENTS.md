# base_project

个人开源项目基础模板。

## 构建

```bash
xmake build          # 构建
xmake -r             # 重新构建
```

`compile_commands.json` 由 xmake 根据真实构建参数自动更新到 `build/`（供 clang-tidy / clangd
使用），无需手动运行。

## 运行

```bash
xmake run app
```

xmake.lua 中已设置 `set_rundir(".")`，xmake run 从项目根目录执行，可直接使用相对路径。

## 项目结构

```
include/          头文件
src/              源文件
tests/            测试样例
docs/             文档
utils/
  check.sh        只读检查（默认智能增量；--staged = pre-commit；--full = CI）
  fix.sh          显式修复空白、EOF 换行和 clang-format，不自动暂存
  lib/            质量脚本共享实现
  tests/          使用临时 Git 仓库验证质量脚本
.githooks/
  pre-commit      转发到 check.sh --staged
.github/
  workflows/
    ci.yml        CI 流水线（push/PR 触发 check.sh）
output/           输出文件 (gitignore)
```

## 关键约定

- C++20 / xmake / GCC 或 Clang 自适应工具链
- GCC 使用系统默认标准库和链接器；Clang 使用 libc++ / lld / compiler-rt / libunwind
- 编译选项 -Wall -Wextra -Werror，零 warning
- clang-tidy `WarningsAsErrors: '*'`，静态分析零容忍
- `<cctype>` 函数传参必须 `static_cast<unsigned char>()`，否则 signed char 有 UB
- `compile_commands.json` 由 xmake 的 `plugin.compile_commands.autoupdate` 规则自动更新
- clang-format / clang-tidy 递归检查 `include/`、`src/` 下的 C/C++ 文件
- C++ 单元测试使用 doctest，源码放在 `tests/unit/`，统一构建为 `unit_tests` target
- `xmake test` 依次运行 doctest 单元测试和 `utils/tests/test_quality_scripts.sh`
- 行尾统一 LF（`.gitattributes` 控制）
- pre-commit hook 转发到 `utils/check.sh --staged`；首次 `xmake build` 自动配置 `core.hooksPath`
- `utils/check.sh` 始终只读；默认智能增量检查工作区变更，`--staged` 只检查 commit 暂存内容，
  `--full` 执行全量 format / tidy / rebuild / test
- `.clang-format` 变化触发全量 format；`.clang-tidy`、xmake.lua 或公共头文件变化触发全量 tidy
- `utils/fix.sh` 仅修复尾随空白、EOF 换行和 clang-format，不运行 tidy/build/test，不执行
  `git add`；修复后人工复查和暂存
- 部分暂存文件不能进入 `--staged` 检查，必须先处理暂存与未暂存修改
- 项目未配置 pre-push hook；push 后由 GitHub Actions 执行 `utils/check.sh --full`
- CI 只使用 Clang，不设置编译器矩阵；xmake 使用 latest，避免在 CI 中重复单独构建

## 开发记录规则

**每次文档或代码变动，必须在 `docs/devlog.md` 中留存痕迹。**

记录格式：
```
### YYYY-MM-DD 简述

- **变更类型**: docs / src / fix / refactor / build / chore
- **涉及文件**: 文件列表
- **变更内容**: 具体做了什么
- **原因**: 为什么做这个变更
- **验证**: 如何验证正确性（测试命令/结果）
```

# base_project

个人开源项目基础模板 — C++20 + xmake + GCC/Clang 自适应工具链。

## 前置条件

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| GCC 或 Clang | GCC 10 / Clang 12 | 支持 C++20 的编译器 |
| xmake | 2.8 | 构建系统 |
| lld | — | Clang 使用的链接器 |
| libc++ | — | Clang 使用的 C++ 标准库 |
| clang-format | — | 代码格式化 (随 clang 提供) |
| clang-tidy | — | 静态分析 (随 clang 提供) |
| perl | — | fix.sh 空白修复 |

doctest 由 xmake/xrepo 在配置或首次运行测试时自动获取。

## 构建

```bash
xmake build                           # 使用 xmake 自动检测的工具链构建
xmake f -c -y --toolchain=gcc         # 显式选择 GCC
xmake f -c -y --toolchain=clang       # 显式选择 Clang
xmake -r                              # 重新构建
```

GCC 使用系统默认的标准库和链接器；Clang 自动启用 libc++、lld、compiler-rt 和
libunwind。

`compile_commands.json` 由 xmake 根据真实构建参数自动更新到 `build/`（供 clang-tidy /
clangd 使用），无需手动生成。

## 首次克隆后设置

首次 `xmake build` 时会自动配置 git hooks。commit 前会只读检查暂存内容，不会自动修改或
暂存文件。

## 质量检查

```bash
utils/check.sh                     # 智能增量检查，再执行增量 build + 全部 test
utils/check.sh --staged            # 只读检查暂存内容（pre-commit 使用）
utils/check.sh --full              # 全量检查、重新构建和测试（CI 使用）
utils/check.sh --skip-tidy         # 跳过静态分析
utils/check.sh --skip-build        # 跳过构建
utils/check.sh --skip-test         # 跳过测试

utils/fix.sh                       # 修复工作区变更中的机械问题
utils/fix.sh --full                # 修复全部适用文件
```

三种运行模式的行为不同：

- 默认模式检查已暂存、未暂存和未跟踪的文件，仅对受影响的源码运行 format/tidy，然后执行
  `xmake build` 和全部测试。
- `--staged` 只读检查本次 commit 的暂存内容，不构建、不测试、不修复。如果同一文件还有未
  暂存修改，检查会停止，避免工作区内容与 commit 快照不一致。
- `--full` 递归检查全部文件，执行 `xmake -r` 和全部测试，供 CI 或发布前验证使用。

`check.sh` 始终只读。空白、EOF 换行或 clang-format 失败时会提示运行 `fix.sh`；`fix.sh` 不
运行 tidy/build/test，也不会执行 `git add`，修复后必须人工检查差异并暂存。

智能增量模式会在影响范围无法局部确定时自动扩大检查：`.clang-format` 变化触发全量 format，
`.clang-tidy` 或 `xmake.lua` 变化以及公共头文件变化触发所有编译单元的 tidy。

## 测试

```bash
xmake test
```

测试使用 doctest。C++ 单元测试统一编译为 `unit_tests`，随后运行质量脚本的临时 Git 仓库集成
测试。新增测试文件放在 `tests/unit/`；测试入口位于 `tests/test_main.cpp`。

自动执行时机：

- `git commit` 前，本地 pre-commit hook 调用 `utils/check.sh --staged`，失败时阻止提交。
- 本项目没有配置本地 pre-push hook，因此 `git push` 前不会再次在本地执行。
- push 到 `main` 或创建/更新 PR 后，GitHub Actions 会运行 `utils/check.sh --full`；这是远端
  检查，push 已经发生，不会在本地阻止 push。

格式化和静态检查会递归扫描 `include/`、`src/`、`tests/` 下的 C/C++ 文件。执行
`xmake test` 会运行 C++ 单元测试和质量脚本集成测试，任何一步失败都会返回非零状态。

## 运行

```bash
xmake run app
```

## 项目结构

```
include/          头文件
src/              源文件
tests/            测试样例
docs/             文档
utils/
  check.sh        只读质量检查（默认增量；--staged = pre-commit；--full = CI）
  fix.sh          显式修复空白、EOF 换行和 clang-format
  lib/            check.sh / fix.sh 的共享实现
  tests/          质量脚本集成测试
.githooks/
  pre-commit      转发到 check.sh --staged
.github/
  workflows/
    ci.yml        CI 流水线（push/PR 触发 check.sh）
output/           输出文件 (gitignore)
```

## CI

push 到 `main` 或提交 PR 时，GitHub Actions 使用 Clang 执行 `utils/check.sh --full`，然后
运行 `app` 冒烟测试。xmake 始终使用 latest 版本。

## 技术栈

C++20 / xmake / GCC 或 Clang（Clang 使用 libc++ / lld / compiler-rt）

## 许可证

Apache License 2.0

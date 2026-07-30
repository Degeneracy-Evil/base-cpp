# base_project

个人开源项目基础模板 — C++20 + xmake + Clang/GCC 工具链。

## 前置条件

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| Clang（默认）或 GCC | Clang 12 / GCC 10 | 支持 C++20 的编译器 |
| xmake | 2.8 | 构建系统 |
| lld | — | Clang 使用的链接器（仅 Clang） |
| libc++ | — | Clang 使用的 C++ 标准库（仅 Clang） |
| clang-format | — | 代码格式化（随 clang 提供） |
| clang-tidy | — | 静态分析（随 clang 提供） |

doctest 由 xmake/xrepo 在配置或首次运行测试时自动获取。

## 构建

```bash
xmake build                           # 使用 Clang 构建（默认工具链）
xmake f -c -y --toolchain=gcc         # 切换到 GCC
xmake -r                              # 重新构建
```

Clang 自动启用 libc++、lld、compiler-rt 和 libunwind；GCC 使用系统默认的标准库和链接器。

首次 `xmake build` 会自动配置 git hooks，后续 commit 前会自动修复格式和尾随空白。

`compile_commands.json` 由 xmake 根据真实构建参数自动更新到 `build/`（供 clang-tidy /
clangd 使用），无需手动生成。

## 质量检查

```bash
git commit        # 自动修复格式 + 尾随空白 → 提交，零摩擦
xmake check       # 全量 format + tidy + rebuild + test（发布前 / CI）
```

日常开发只需 `git commit`，pre-commit hook 会自动对暂存文件运行 clang-format 并清理尾随
空白和 EOF 换行，修复后自动重新暂存，整个过程无感。

发布前或 CI 中执行 `xmake check`，依次运行 clang-format、clang-tidy、`xmake -r` 和
`xmake test`，任何一步失败都会返回非零状态。

格式化和静态检查递归扫描 `include/`、`src/`、`tests/` 下的 C/C++ 文件。行尾统一 LF
（`.gitattributes` 控制）。

## 测试

```bash
xmake test
```

测试使用 doctest。C++ 单元测试统一编译为 `unit_tests`。新增测试文件放在 `tests/unit/`；
测试入口位于 `tests/test_main.cpp`。

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
.githooks/
  pre-commit      自动修复格式 + 尾随空白并重新暂存
.github/
  workflows/
    ci.yml        CI 流水线（push/PR 触发 xmake check）
AGENTS.md         AI 代理开发约定
LICENSE           Apache License 2.0
output/           输出文件 (gitignore)
```

## CI

push 到 `main` 或提交 PR 时，GitHub Actions（ubuntu-24.04）使用 Clang 执行
`xmake check`，然后运行 `xmake run app` 冒烟测试。xmake 始终使用 latest 版本。

## 技术栈

C++20 / xmake / Clang 或 GCC（Clang 使用 libc++ / lld / compiler-rt / libunwind）

## 许可证

Apache License 2.0

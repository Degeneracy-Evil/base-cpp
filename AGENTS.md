# base-cpp

面向个人 C++ 工程的现代、严格、轻量项目模板，不是通用 framework 或发布型 library 模板。

## 环境与构建

- 使用 C++23 和 xmake，不引入第二套构建系统。
- Clang 是主要/默认工具链，GCC 是可选工具链。
- 使用所选 toolchain 的默认 C++ 标准库、链接器和 runtime，不默认强制 libc++、lld、
  compiler-rt 或 libunwind。

```bash
xmake f -c -y --toolchain=clang
xmake
xmake -r
```

`compile_commands.json` 由 xmake 自动更新到 `build/`。

## 运行

```bash
xmake run app
```

程序从项目根目录运行。

## 格式化

```bash
xmake format
```

这是显式的 mutating 操作，会格式化 `include/`、`src/` 和 `tests/` 中受管理的 C/C++ 文件。

## 完整验证

```bash
xmake check
```

这是 non-mutating full validation：检查 clang-format，刷新 compilation database，运行
clang-tidy、rebuild 和 doctest。它不得修改 tracked 文件。

## 关键工程约定

- app 与单元测试统一使用 `-Wall -Wextra -Werror -Wpedantic`，保持零 warning。
- clang-tidy 的所有 warning 视为 error；不要无理由扩大 lint 规则面。
- 保持现有 clang-format 风格和 120 列行宽。
- 单元测试使用 doctest；入口为 `tests/test_main.cpp`，测试源码放在 `tests/unit/`。
- C/C++ 文件使用 4 个空格；仓库文本统一为 LF。
- pre-commit hook 只验证 staged snapshot，不修改 working tree 或 index；安装命令为
  `git config core.hooksPath .githooks`。
- 不无理由引入新 dependency、framework、build system、coverage、benchmark 或 CI matrix。

## 修改后的必做验证

修改代码或配置后必须执行：

```bash
xmake check
xmake run app
```

涉及工具链或构建行为时，还应使用相关工具链从 clean configuration 验证。

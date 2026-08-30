# base-cpp

面向个人 C++ 工程的现代、严格、轻量项目模板，使用 C++23、xmake 和 Clang/GCC。

## 前置条件

- 支持 C++23 的 Clang（默认）或 GCC；
- xmake；
- clang-format；
- clang-tidy。

主要验证环境为 Ubuntu 24.04、Clang 和最新版 xmake。GCC 是可选的本地工具链。构建使用所选
toolchain 在当前环境中的默认 C++ 标准库、链接器和 runtime，不强制绑定 LLVM runtime stack。

doctest 由 xmake/xrepo 在配置或首次运行测试时自动获取。

## 初始化

从 GitHub template 创建仓库或 clone 后，安装本仓库的 Git hook：

```bash
git config core.hooksPath .githooks
```

## 构建

```bash
xmake f -c -y --toolchain=clang    # 配置默认 Clang 工具链
xmake                              # 构建
xmake -r                           # 重新构建
xmake f -c -y --toolchain=gcc      # 切换到 GCC
```

`compile_commands.json` 由 xmake 根据真实构建参数自动更新到 `build/`，供 clang-tidy 和 clangd
使用。

## 运行

```bash
xmake run app
```

xmake 从项目根目录运行程序，因此程序可以直接使用相对于根目录的路径。

## 格式化

```bash
xmake format
```

此命令会使用 clang-format 原地修改 `include/`、`src/` 和 `tests/` 中受管理的 C/C++ 文件。

## 完整质量检查

```bash
xmake check
```

此命令依次检查格式、刷新 compilation database、运行 clang-tidy、重新构建并运行单元测试。
它只验证 tracked 文件，不会修改它们；构建产物仍会写入已忽略的目录。

## 测试

```bash
xmake test
```

单元测试使用 doctest，入口位于 `tests/test_main.cpp`，测试源码放在 `tests/unit/` 并统一构建为
`unit_tests` target。

## Git hook

pre-commit hook 快速检查 Git index 中即将提交的 snapshot：

- `git diff --cached --check` 检查 staged whitespace error；
- clang-format 检查 staged C/C++ 内容。

hook 不读取未暂存的 C/C++ 修改，不修改 working tree，也不调用 `git add`。存在 staged C/C++
文件但缺少 clang-format 时，commit 会失败并显示安装提示。

## CI

push 到 `main` 或提交 pull request 时，GitHub Actions 在 Ubuntu 24.04 上使用 Clang 运行
`xmake check`，随后以 `xmake run app` 做 smoke test。CI 只授予只读 repository contents 权限。

## 从模板开始新项目

创建项目后，应按项目需要修改 `set_project` / `set_version`、README、程序源码和测试。仅在具体
项目确有需要时增加依赖、library target、其他构建系统或额外 CI matrix。

## 许可证

[Apache License 2.0](LICENSE)

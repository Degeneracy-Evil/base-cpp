# base-cpp

个人 C++23 工程模板，使用 xmake，默认 Clang，亦可切换 GCC。

## 初始化

```bash
git config core.hooksPath .githooks
xmake f -c -y --toolchain=clang
xmake
```

## 运行

```bash
xmake run app
```

## 格式化

```bash
xmake format
```

## 检查

```bash
xmake check
```

完整检查包含 clang-format、clang-tidy、重新构建和 doctest，且不会修改 tracked 文件。

单独运行测试：

```bash
xmake test
```

基于此模板建立具体项目后，请按实际项目重写 README 和 AGENTS.md。

## License

Apache-2.0

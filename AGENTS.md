# base-cpp

本仓库是 C++ 项目的起始模板。

- 使用 C++23 和 xmake；Clang 为默认工具链，GCC 可选。
- clang-format 负责格式化，clang-tidy 负责静态检查。
- 编译 warning 和 clang-tidy warning 均视为错误。
- 单元测试使用 doctest。
- 完整检查必须保持 non-mutating。
- pre-commit 只检查 staged snapshot，不修改文件，也不自动 stage。
- 不无理由增加第二套构建系统、重复工具或 framework。

修改后执行：

```bash
xmake check
xmake run app
```

具体项目结构建立后，请用项目自己的约定重写本文件。

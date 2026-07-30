# 开发记录

### 2026-07-30 添加 VERSION 文件为版本唯一真相源

- **变更类型**: src / build / docs
- **涉及文件**: VERSION, xmake.lua, README.md, AGENTS.md, docs/devlog.md
- **变更内容**: 新增 VERSION 文件（0.1.0）为版本唯一真相源；xmake check 版本校验改为三方比对（VERSION vs xmake.lua vs version.hpp）；更新文档说明版本同步约定。
- **原因**: VERSION 文件是最通用、最简单的版本定义方式，任何工具和人都能直接读取。xmake.lua 和 version.hpp 需手动同步，xmake check 在 CI 中自动校验。
- **验证**: xmake check 通过（含版本三方校验步骤）

### 2026-07-30 简化版本校验及调整格式配置

- **变更类型**: fix / chore
- **涉及文件**: xmake.lua, .clang-format, docs/devlog.md
- **变更内容**: 版本校验去掉 python3 依赖，改为 sed 直接从 xmake.lua 提取 set_version；PointerAlignment 改为 Right；ColumnLimit 改为 120。
- **原因**: 原 awk+python3+json 校验命令过于复杂且引入不必要的 python3 依赖；sed 读 xmake.lua 更简单直接。格式偏好调整。
- **验证**: xmake check 通过（含版本校验步骤）

### 2026-07-30 添加 version.hpp 及版本一致性校验

- **变更类型**: src / build
- **涉及文件**: include/version.hpp, xmake.lua, docs/devlog.md
- **变更内容**: 新增 include/version.hpp 定义 PROJECT_VERSION_MAJOR/MINOR/PATCH 宏及 PROJECT_VERSION 字符串宏（预处理器 stringify 自动拼接）；xmake check 新增 [1/5] 版本一致性校验步骤，从 version.hpp 提取版本号与 xmake.lua set_version() 比对，不一致则报错退出。
- **原因**: 版本号散落在多处容易遗漏同步。version.hpp 为唯一真相源（C++ 代码直接 #include），xmake.lua 保留 set_version 供 xmake 打包/安装使用，xmake check 在 CI 和发布前自动校验两者一致。
- **验证**: xmake build 通过、xmake test 通过、xmake check 通过（含版本校验步骤）；故意制造 mismatch 后 xmake check 正确报错

### 2026-07-29 修复 hooksPath 配置 bug 及扫描遗留问题

- **变更类型**: fix / chore / docs
- **涉及文件**: xmake.lua, .clang-tidy, AGENTS.md, README.md, docs/devlog.md, tests/.gitkeep (deleted)
- **变更内容**: 修复 xmake.lua on_load hook 中 os.runv 不对非零退出码 raise 的 bug（改为 os.execv，确保 hooksPath 未设置时能正确配置）；删除冗余的 tests/.gitkeep（tests/ 已有跟踪内容）；.clang-tidy HeaderFilterRegex 补 .h 匹配；AGENTS.md 项目结构补 AGENTS.md 和 LICENSE；README.md 前置条件表 lld/libc++ 标注"仅 Clang"。
- **原因**: 全面扫描发现 on_load hook 中 os.runv 导致 hooksPath 永远不会被设置（Lua 中非零退出码是 truthy，try 不会捕获）；tests/.gitkeep 在目录已有内容后冗余；HeaderFilterRegex 遗漏 .h 头文件；文档结构图和前置条件表存在不一致。
- **验证**: xmake build 通过（构建时自动配置 core.hooksPath）、xmake test 通过、xmake check 通过

### 2026-07-29 简化质量检查：合并 check/fix 为 xmake check，pre-commit 自动修复

- **变更类型**: refactor / chore / docs
- **涉及文件**: xmake.lua, .githooks/pre-commit, .github/workflows/ci.yml, README.md, AGENTS.md, docs/devlog.md, utils/ (deleted)
- **变更内容**: 将 utils/check.sh + utils/fix.sh + utils/lib/quality_common.sh + utils/tests/ 合并为 xmake check task（全量 format+tidy+rebuild+test）；pre-commit 从只读检查改为自动修复（format+空白+git add）；删除增量/暂存/skip 模式；CI 简化为 xmake check；Clang 设为默认工具链（set_toolchains("clang", "gcc")）；用 sed 替代 perl 修复空白；删除 utils/ 目录。
- **原因**: 个人脚手架质量检查过于复杂（3 模式+3 skip+4 脚本 494 行），日常使用摩擦大。简化为 xmake check 一条命令 + git commit 自动修复，覆盖 90% 使用场景。
- **验证**: xmake build 通过、xmake test 通过、xmake check 通过、pre-commit hook 自动修复验证通过

### 2026-07-28 修复文档与实际项目状态的不一致

- **变更类型**: docs
- **涉及文件**: docs/devlog.md, README.md, AGENTS.md, utils/check.sh, utils/fix.sh, utils/lib/quality_common.sh
- **变更内容**: devlog 补充 11 个 CI 迭代 commit 的记录，修正 4 条条目日期 2026-07-16→2026-07-28；README 项目结构图添加 AGENTS.md 和 LICENSE，技术栈摘要补充 libunwind，CI 段注明 ubuntu-24.04，格式化段补充 .gitattributes LF 行尾说明；AGENTS.md format/tidy 范围补充 tests/，check.sh 默认模式描述补充 build+test 和 --skip-* 标志，fix.sh 描述补充 --full，CI 描述补充冒烟测试，补充 perl 依赖说明；check.sh 和 fix.sh 头注释补充缺失的 CLI 标志；quality_common.sh 添加 section 分隔注释和关键函数的作用说明（特别是 collect_all_format_files 与 collect_all_tidy_files 的搜索范围差异）。
- **原因**: 文档审查发现 devlog 缺失 11 个 commit 记录和 4 条日期错误（CRITICAL），README/AGENTS.md 存在误导性遗漏（MODERATE），脚本头注释不完整（MODERATE），以及多处 MINOR 级别的文档与实际行为不一致。
- **验证**: `utils/check.sh --staged` 通过；人工核对所有修改点与审查报告一致。

### 2026-07-28 引入 doctest、重构质量脚本并简化 CI

- **变更类型**: build / test / refactor / docs
- **涉及文件**: xmake.lua, tests/test_main.cpp, tests/unit/test_example.cpp, utils/check.sh, utils/fix.sh, utils/lib/quality_common.sh, utils/tests/test_quality_scripts.sh, .github/workflows/ci.yml, README.md, AGENTS.md, docs/devlog.md
- **变更内容**: 通过 xmake/xrepo 引入 doctest，新增 unit_tests target 和真实示例测试；xmake test 统一运行 C++ 单元测试与质量脚本集成测试；抽取 quality_common.sh 复用 Git 文件收集和文件类型判断，format/tidy 扩展覆盖 tests；集成测试在临时 Git 仓库中验证只读检查、显式修复、空格路径、暂存/部分暂存和智能全量升级；CI 简化为单一 Clang 流程，移除编译器矩阵和重复 Build 步骤，保留 latest xmake。
- **原因**: 建立真实测试闭环，降低 check.sh/fix.sh 的重复实现和维护成本，并让 CI 保持符合个人项目规模的简单流程。
- **验证**: Shell 语法检查通过；`utils/tests/test_quality_scripts.sh` 全部通过；doctest 已被 xmake 解析为 2.4.12，但直接下载及调用 `.zshrc` 的 `proxyon` 后下载均因 `Recv failure: Connection reset by peer` 失败；通过同一代理独立执行 curl 也复现该错误。因此 unit_tests、xmake test 和依赖它们的全量检查尚未完成运行验证。

### 2026-07-28 修正 clangd 工具链参数来源

- **变更类型**: fix / docs
- **涉及文件**: .clangd, docs/devlog.md
- **变更内容**: 移除 `.clangd` 中硬编码的 `-std=c++23` 和 `-stdlib=libc++`，仅保留 `build/compile_commands.json` 作为编译参数来源。
- **原因**: 项目已切换为 C++20 和 GCC/Clang 自适应工具链，固定追加 C++23/libc++ 会覆盖或污染真实构建配置。
- **验证**: 确认 Clang 生成的 compilation database 包含 C++20/libc++ 参数，GCC 生成的 compilation database 包含 C++20 且不包含 libc++；`clangd --check=src/main.cpp` 和 `git diff --check` 通过。

### 2026-07-28 分离只读检查与显式修复

- **变更类型**: build / chore / docs
- **涉及文件**: utils/check.sh, utils/fix.sh, .githooks/pre-commit, .github/workflows/ci.yml, README.md, AGENTS.md, docs/devlog.md
- **变更内容**: 将 check.sh 重构为只读的默认智能增量、`--staged` 和 `--full` 三种模式；配置或公共头文件变化时自动扩大 format/tidy 范围；新增 fix.sh，独立修复尾随空白、EOF 换行和 clang-format，且不自动暂存；pre-commit 改为检查暂存内容，CI 保持全量检查；不同失败类型输出针对性处理建议。
- **原因**: 分离检查与修改职责，保证日常检查和 commit hook 不会隐式改动工作区，同时兼顾本地反馈速度、commit 快照准确性和 CI 完整性。
- **验证**: `bash -n utils/check.sh utils/fix.sh` 通过；临时未跟踪源码验证 check.sh 失败时保持文件哈希不变、fix.sh 能修复空白和格式且不暂存；空暂存区的 `--staged` 只读路径通过；GCC/Clang 下 `utils/check.sh --full` 均 5/5 通过且 app 正常运行；`git diff --check` 通过。部分暂存拒绝逻辑因当前环境禁止写 Git index，仅完成代码审查，未执行集成测试。

### 2026-07-28 同步基础工程模板更新

- **变更类型**: build / chore / docs
- **涉及文件**: xmake.lua, utils/check.sh, .github/workflows/ci.yml, .clang-format, .gitignore, README.md, AGENTS.md, docs/devlog.md
- **变更内容**: 将语言标准调整为 C++20，支持 GCC/Clang 自适应工具链；Clang 条件启用 libc++、lld、compiler-rt 和 libunwind；使用 xmake 官方规则按真实构建参数自动更新 compile_commands.json；质量脚本递归检查 C/C++ 文件并通过显式 xmake task 运行测试；CI 增加 GCC/Clang 矩阵和 app 冒烟运行；同步 clang-format 配置并忽略 .xrepo/。
- **原因**: 吸收 sysal 项目中已经验证的通用基础设施改进，使模板适用于多层源码目录和两套主流编译器，并消除手写 compilation database 可能过期或参数不完整的问题。
- **验证**: `bash -n utils/check.sh` 通过；GCC 下 `xmake f -c -y --toolchain=gcc && xmake -r && xmake run app && xmake test` 通过；Clang 下 `xmake f -c -y --toolchain=clang && xmake -r && xmake run app` 通过；两套工具链生成的 `build/compile_commands.json` 均包含真实编译器和 `-std=c++20`；`utils/check.sh` 全量检查 4/4 通过。

### 2026-06-20 CI 工作流迭代与修复

- **变更类型**: fix / ci
- **涉及文件**: .github/workflows/ci.yml
- **变更内容**: 经过 11 次迭代修复 CI 工作流：将 libunwind-dev 拆分安装以避免 apt 冲突；切换到 xmake-io/github-action-setup-xmake 官方 action；在 check 前生成 compile_commands.json 以修复 libc++ 头文件发现；引入 LLVM apt 仓库使 libc++ 头文件进入 Clang 搜索路径；切换到 Ubuntu 默认 toolchain + build-essential 并开启 verbose build 调试；固定 ubuntu-24.04 + clang-18 并添加诊断步骤；拆分 libunwind-dev 安装并将诊断移至构建前；创建 libc++ 头文件符号链接到 Clang 预期路径；使用 libunwind-18-dev 并添加验证步骤；清理工作流移除 -18 后缀和诊断步骤；最终添加 xmake configure 步骤并移除 --skip-build 和 compile_commands 手动生成。
- **原因**: 初始 CI 工作流在 ubuntu-24.04 上无法正确找到 libc++ 头文件和链接 libunwind，导致 clang-tidy 和构建失败。需要逐步调试并修复 apt 包冲突、头文件搜索路径和 xmake 与系统工具链的集成问题。
- **验证**: 最终 CI 工作流在 GitHub Actions 上成功运行，`utils/check.sh --full` 全部通过，`xmake run app` 冒烟测试输出 "Hello, World!"。

### 2026-06-20 初始化项目基础设施

- **变更类型**: chore / build / docs
- **涉及文件**: xmake.lua, .clang-format, .clang-tidy, .clangd, .gitignore, .githooks/pre-commit, utils/check.sh, README.md, AGENTS.md, src/main.cpp, LICENSE
- **变更内容**: 从 lzu/compiler_principles 项目迁移基础设施模板，包括 xmake 构建配置（C++23/clang/libc++/lld）、clang-format 格式化规则、clang-tidy 静态分析配置、clangd IDE 集成、git hooks（pre-commit 转发到 check.sh）、统一质量检查脚本（hook/全量双模式）、README 和 AGENTS 文档。泛化了 target 名称为 "app"，移除了项目特定的宏定义（SPDLOG/TOML），测试部分留为 TODO 占位符。
- **原因**: 作为个人开源项目的基础模板，需要一套完整的、开箱即用的 C++ 工程基础设施
- **验证**: `xmake build` 通过，`xmake run app` 输出 "Hello, World!"，`utils/check.sh` 全量检查 4/4 通过，pre-commit hook 成功运行 clang-tidy 并通过

### 2026-06-20 模板改进：空目录占位、CI、前置条件、clang-tidy 零容忍、gitattributes、compile_commands 自动生成

- **变更类型**: chore / build / docs / ci
- **涉及文件**: include/.gitkeep, tests/.gitkeep, .github/workflows/ci.yml, README.md, AGENTS.md, .clang-tidy, .gitattributes, xmake.lua
- **变更内容**:
  1. 添加 `include/.gitkeep` 和 `tests/.gitkeep`，确保空目录被 git 跟踪
  2. 创建 `.github/workflows/ci.yml`，push/PR 时自动安装工具链并运行 `utils/check.sh`
  3. README 添加前置条件表格（clang/xmake/lld/libc++/clang-format/clang-tidy/perl）
  4. `.clang-tidy` 设置 `WarningsAsErrors: '*'`，静态分析零容忍
  5. 创建 `.gitattributes`，统一行尾为 LF
  6. `xmake.lua` 添加 `after_build` 钩子，构建后自动生成 `compile_commands.json`（手动构造 JSON，避免 xmake 递归调用死锁）
- **原因**: 提升模板的开箱即用性和 CI 就绪度，统一零容忍质量策略
- **验证**: `xmake -r` 后 `compile_commands.json` 自动生成且 JSON 合法，`utils/check.sh` 4/4 通过，clang-tidy exit code 0

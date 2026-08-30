# base-cpp v2 重构设计

> 状态：Approved for implementation  
> 目标分支：`main`  
> 适用仓库：`Degeneracy-Evil/base-cpp`  
> 本文是本轮重构的实施依据。实现 Agent 应以本文的目标、边界和验收标准为准，不应在本轮自行扩展工程范围。

## 1. 背景

`base-cpp` 是个人 C++ 工程的 GitHub template，目标是为新项目提供一个现代、严格、低维护、可直接开始开发的工程基线，而不是构造一个功能齐全的 C++ framework。

当前仓库已经具备一套可用的基础设施：

- xmake 构建系统；
- Clang 默认、GCC 可选；
- clang-format；
- clang-tidy；
- `-Wall -Wextra -Werror`；
- doctest 单元测试；
- `compile_commands.json` 自动生成；
- Git hook；
- GitHub Actions CI；
- Apache-2.0。

本轮不是推倒重写，而是进行一次规范化重构，使它：

1. 与后续的 `base-py`、`base-rust` 共享统一的工程哲学；
2. 清理历史上逐步加入、但不适合作为通用 template 默认策略的配置；
3. 明确区分“修改代码”和“验证代码”；
4. 让 CI green 严格代表当前 commit 本身满足工程规范；
5. 保持模板轻量，不引入无必要的工具和依赖。

---

## 2. base-* Family Contract

本轮 `base-cpp` 应遵循下面的三语言共同约定。语言生态无法统一的部分采用各自的原生方案，不为了目录或命令表面一致而增加抽象层。

| 维度 | 共同原则 |
|---|---|
| 定位 | 个人工程项目模板，不是发布型 library/package 模板 |
| 版本策略 | 使用当前最新正式稳定语言代际，不主动兼容陈旧环境 |
| Runtime 依赖 | 默认尽可能为 0 |
| Format | 使用语言生态标准 formatter |
| 行宽 | 支持时统一为 120 |
| Warning / lint | 严格；warning 视为错误 |
| Check | 完整质量检查必须是 non-mutating validation |
| Format / fix | 显式执行，允许修改工作区 |
| Git hook | 快速、确定、只检查 staged snapshot；不得自动修改或自动 stage |
| Lock | 生态可靠支持时提交 lock 并在 CI 验证 |
| Coverage | base template 不设置 coverage hard gate |
| 行尾 | LF |
| CI | Ubuntu 24.04；main push + pull request；最小只读权限 |
| Smoke test | 必须存在 |
| README / AGENTS | 三库结构和核心语义尽可能一致 |
| Devlog | base template 不强制维护开发日志 |
| License | Apache-2.0 |

C++ 中的具体实现仍应保持 C++ 原生：

- xmake；
- clang-format；
- clang-tidy；
- doctest；
- Clang / GCC。

---

## 3. 本轮目标

### 3.1 升级语言基线到 C++23

将模板语言标准从 C++20 升级到 **C++23**。

`xmake.lua` 中应使用 C++23。README 和 AGENTS 中所有 C++20 描述同步更新。

模板的主要验证环境仍为：

- Ubuntu 24.04；
- Clang；
- xmake。

GCC 保持为可选工具链，但本轮不增加 CI compiler matrix。

不要为了声明“兼容非常老的 C++23 编译器”而人为降低功能或增加兼容层。README 中的工具版本描述应与实际验证环境一致；若无法给出经过验证的精确最低编译器版本，不要保留历史上的 Clang 12 / GCC 10 这类失真的最低版本声明。

### 3.2 保持模板轻量

继续保留现有核心技术栈，不引入：

- CMake；
- Conan；
- vcpkg；
- Meson；
- Bazel；
- Catch2；
- GoogleTest；
- 自定义 task runner；
- coverage 工具；
- benchmark 框架；
- sanitizer 默认流水线；
- 多平台 CI matrix；
- 多编译器 CI matrix。

这些能力应由具体项目按需要增加，而不是成为 base template 的默认成本。

---

## 4. 质量命令语义

这是本轮最重要的行为变更之一。

### 4.1 `xmake format`

新增一个显式的 **mutating** format task：

```bash
xmake format
```

职责仅为：

- 对仓库受管理的 C/C++ 文件执行 clang-format；
- 允许直接修改工作区文件。

格式化范围应覆盖：

- `include/`
- `src/`
- `tests/`

中的：

- `*.h`
- `*.hpp`
- `*.c`
- `*.cpp`

如以后增加其他 C++ 后缀，可再按项目需要扩展。

### 4.2 `xmake check`

`xmake check` 必须改成纯 **validation**，不得格式化或修改任何 tracked source/config/document file。

建议语义顺序：

1. clang-format check；
2. 生成或刷新 compilation database；
3. clang-tidy；
4. rebuild；
5. unit tests。

即概念上：

```text
format --check
    ↓
clang-tidy
    ↓
build
    ↓
test
```

允许 `xmake check` 写入 `build/`、`.xmake/` 等已经被忽略的构建目录；“non-mutating”指不得改变 Git tracked 工作区内容。

完成后，在一个原本 clean 的 repository 中：

```bash
git status --short
```

仍应为空。

不要为了保持旧实现方便而继续在 check 中调用：

```text
clang-format -i
```

CI 也不得依赖“先自动修复再通过”。

### 4.3 Format check 实现要求

实现可以使用 xmake/Lua 或调用外部命令，但需要满足：

- 所有目标文件都被检查；
- 任意一个文件不符合 clang-format 时返回非零；
- 不修改源文件；
- 路径中存在空格时不能出现明显的 shell splitting bug；
- 空目录/没有匹配文件时行为合理。

如果使用 shell pipeline，应特别注意 `find` / `xargs` 的 NUL 分隔以及空输入行为。若 xmake 原生 API 能更简单可靠地枚举文件，优先使用原生方式，避免为了任务编排堆叠 Bash 技巧。

---

## 5. Git hook 重构

当前 hook 会直接修改 working tree 中的 staged 文件，然后 `git add` 整个文件。这在 partial staging 场景存在把原本未暂存修改一起加入 commit 的风险。

本轮必须移除这一行为。

### 5.1 新 hook 的原则

`.githooks/pre-commit` 应：

- 只检查；
- 不修改任何文件；
- 不调用 `git add`；
- 不隐藏错误；
- 只针对 staged snapshot 做判断；
- 足够快，不运行 clang-tidy、build 或 test。

建议检查两类问题：

1. Git 自身 staged whitespace error：
   `git diff --cached --check`
2. staged C/C++ 文件是否符合 clang-format。

### 5.2 必须检查 staged snapshot，而不是整个 working-tree 文件

这是实现中的重要细节。

例如：

```text
foo.cpp
├── hunk A：已 staged
└── hunk B：未 staged
```

hook 应验证“将要提交的 index 内容”，不能读取整个 working-tree `foo.cpp` 后得出结论，更不能格式化整个文件。

可以通过 Git index（例如 `git show :path` 等方式）获取 staged blob，再用 clang-format 对其进行只读比较。具体实现由 Agent 决定，但必须保证 partial staging 安全。

### 5.3 工具缺失

如果存在 staged C/C++ 文件而系统找不到 clang-format：

- hook 应失败；
- 输出清晰的错误和安装提示；

不要像旧 hook 一样 silently skip formatting validation。

### 5.4 Hook 安装

删除 `xmake.lua` 中自动修改：

```text
git config core.hooksPath
```

的逻辑。

README 明确要求 clone/template 初始化后执行一次：

```bash
git config core.hooksPath .githooks
```

工程配置不应在普通 build 过程中隐式修改 Git repository config。

---

## 6. Toolchain 策略

### 6.1 Clang / GCC

继续：

- Clang 作为默认/主要工具链；
- GCC 作为可选工具链；
- CI 仅验证 Clang。

不要增加 compiler matrix。

### 6.2 移除 Clang runtime 强绑定

删除当前 `configure_toolchain()` 对 Clang 强制注入的：

- `-stdlib=libc++`
- `-fuse-ld=lld`
- `-rtlib=compiler-rt`
- `-unwindlib=libunwind`

以及相关专用配置逻辑。

理由：

“使用 Clang 编译器”和“选择 libc++ / lld / compiler-rt / libunwind”是两个独立决策。一个通用个人项目模板不应默认把它们绑定。

新的默认语义应为：

> 使用所选编译器，并采用该环境/toolchain 的正常默认 C++ standard library、linker 和 runtime。

具体项目如果确实需要 LLVM runtime stack，再自行显式配置。

### 6.3 Warning policy

保留：

- `-Wall`
- `-Wextra`
- `-Werror`

建议增加：

- `-Wpedantic`

前提是模板本身和 doctest 当前版本能在目标 Clang 环境下稳定通过。

不要在 base template 中默认加入高噪声、项目相关性很强的：

- `-Wconversion`
- `-Wsign-conversion`
- 大量非默认 sanitizer flags

等策略。

app 与 unit test target 应保持一致的核心 warning policy；测试如确有必要可保留 `-UNDEBUG`。

---

## 7. clang-format

现有风格总体保留，不进行审美重构。

继续保留核心约定：

- LLVM base；
- Allman braces；
- 4 spaces；
- no tabs；
- 120 columns；
- sorted includes；
- right pointer alignment；
- namespace indentation；
- namespace closing comments。

本轮目标是统一工程行为，而不是重新讨论 C++ 排版风格。

如当前 clang-format 配置在 Ubuntu 24.04 所使用的版本出现 deprecated/invalid option，应做最小兼容性修正，并在实施总结中说明。

---

## 8. clang-tidy

现有 clang-tidy 采用 curated checks，而不是开启所有规则。这个方向保留。

继续保留：

- bugprone；
- clang-analyzer；
- performance；
- 一组经过选择的 modernize/readability；
- `WarningsAsErrors: '*'`。

不要在本轮突然启用完整：

- `cppcoreguidelines-*`
- `hicpp-*`
- `cert-*`
- `readability-*`

然后通过大量 ignore 来压回去。

这会把“规范化重构”变成 lint policy 重写。

实施时应使用目标 Clang/clang-tidy 版本实际运行当前规则集：

- 若某个 check 已删除、重命名或不再存在，做最小更新；
- 不因为升级 C++23 就无理由扩大 lint surface；
- 所有最终启用的 clang-tidy warning 继续作为 error。

---

## 9. clangd

保留：

- compilation database 位于 `build`；
- background index；
- unused includes strict；
- inlay hints。

删除：

```yaml
Diagnostics:
  Suppress:
    - pp_file_not_found
```

或等价的全局 `pp_file_not_found` suppression。

缺失头文件是重要的真实诊断，不应由 base template 全局隐藏。若旧配置是为 compilation database 尚未生成时减少噪声而存在，应通过正确生成 compile commands 来解决，而不是屏蔽诊断。

---

## 10. 项目 metadata 与 `version.hpp`

删除模板当前自定义的：

```text
include/version.hpp
PROJECT_VERSION_MAJOR
PROJECT_VERSION_MINOR
PROJECT_VERSION_PATCH
PROJECT_VERSION
```

以及 README / AGENTS 对这套版本宏的约定。

原因：

- 这是独立于构建系统的第二套 metadata；
- base template 本身没有需要在程序中暴露版本号的需求；
- 它让新项目一开始就承担同步版本状态的成本。

如果希望保留 template metadata，可在 xmake 中使用其原生 project/version metadata（例如项目名和 `0.1.0`），但不要重新生成第二份 C++ 宏版本系统。

`include/` 目录可以继续保留为未来公共头文件目录，即使初始状态只有 placeholder。

---

## 11. 测试

继续使用 doctest，不更换测试框架。

继续保留：

- `tests/test_main.cpp` 作为 doctest main；
- `tests/unit/` 作为单元测试目录；
- `unit_tests` target；
- `xmake test` 作为测试入口。

当前 template 应补充至少一个**真正会被 doctest 发现并执行的最小测试**，目的是验证测试基础设施不是“只有 test runner、没有 test”。

这个测试不需要为了追求“测试业务逻辑”而人为增加 library architecture。一个明确标注为 template/sanity 的最小测试即可。

要求：

- `xmake test` 实际显示并执行测试；
- `xmake check` 包含它；
- CI 验证它。

本轮不增加 coverage threshold 或 coverage dependency。

---

## 12. `.editorconfig`

新增根目录 `.editorconfig`，作为三个 base repository 的共同基础配置。

建议至少表达：

- `root = true`
- UTF-8；
- LF；
- final newline；
- space indentation；
- C/C++ 4 spaces；
- 通用 trailing whitespace policy。

注意 Markdown 中 trailing whitespace 可能具有语义；如果启用通用 trim，应为 Markdown 做合理例外，避免破坏 Markdown hard line break。

`.gitattributes` 继续保留：

```text
* text=auto eol=lf
```

两者职责不同：

- EditorConfig 约束 editor 行为；
- gitattributes 约束 Git checkout/normalization。

---

## 13. CI

CI 继续：

- `push: main`
- `pull_request`
- `ubuntu-24.04`
- Clang only
- quality check
- smoke run

新增顶层：

```yaml
permissions:
  contents: read
```

使权限与其他 base repository 的共同约定一致。

### 13.1 Action version policy

不要使用：

```text
uses: ...@latest
```

Action 至少使用明确 major/release tag；若仓库既有的其他 base template 已采用更新且经过验证的官方 action major，可对齐该版本。

尤其应移除当前：

```text
awalsh128/cache-apt-pkgs-action@latest
```

本轮优先考虑简单可靠：

- 直接 apt 安装必要系统包；
- 使用 xmake setup action 自身提供的合适 cache 能力。

不要为了缓存少量 apt 包引入一个无固定版本的额外第三方 action。

### 13.2 CI 系统依赖

移除 Clang runtime 强绑定后，CI 不再因为 template 本身强制需要：

- libc++；
- libc++abi；
- lld；
- compiler-rt；
- libunwind。

只安装实际构建/检查需要的包。

具体包列表以 Ubuntu 24.04 CI 实际验证为准，避免保留不再使用的历史依赖。

### 13.3 CI 质量语义

CI 中的 quality step 使用新的 non-mutating：

```bash
xmake check
```

随后：

```bash
xmake run app
```

做 smoke test。

CI 不应先执行 `xmake format`。

一个格式错误的 commit 应直接 CI fail，而不是被 CI 修改后通过。

---

## 14. README 重写目标

README 应与后续 `base-py` / `base-rust` 采用近似结构，但保留 C++ 自己的命令。

建议结构：

1. `# base-cpp`
2. 一句话定位
3. Prerequisites / 前置条件
4. Start / 初始化
5. Build / 构建
6. Run / 运行
7. Format / 格式化
8. Check / 完整质量检查
9. Test / 测试
10. Git hook
11. CI
12. 从模板开始后应修改什么
13. License

README 必须明确：

- C++23；
- xmake；
- Clang default / GCC optional；
- 使用系统/toolchain 默认 runtime；
- `xmake format` 会修改文件；
- `xmake check` 不修改 tracked files；
- hook 只检查 staged snapshot；
- hook 安装是显式命令；
- doctest；
- CI 平台和行为。

删除所有已经失效的历史描述：

- C++20；
- Clang 12 / GCC 10（除非重新实测并仍决定支持）；
- Clang 强制 libc++/lld/compiler-rt/libunwind；
- 首次 build 自动配置 hook；
- commit 自动修改并重新 stage；
- check 自动 format。

---

## 15. AGENTS.md 重写目标

AGENTS 应成为“Agent 如何正确修改该工程”的简明契约，而不是项目历史记录。

建议结构：

1. 项目定位；
2. 环境与构建；
3. 运行；
4. 格式化；
5. 完整验证；
6. 关键工程约定；
7. 修改后的必做验证。

必须包含：

- C++23；
- xmake only；
- Clang primary / GCC optional；
- 不默认强制 LLVM runtime stack；
- zero warning；
- clang-format；
- clang-tidy warnings as errors；
- doctest；
- LF；
- `xmake format` 是显式 mutation；
- `xmake check` 是 non-mutating full validation；
- 修改代码/配置后必须执行 `xmake check` 和 smoke run；
- 不无理由引入新 dependency / framework / build system。

删除：

- `version.hpp` 约定；
- 自动 hook install 描述；
- hook 自动修复/自动 stage 描述；
- 强制 devlog 规则。

---

## 16. Devlog policy

删除：

```text
docs/devlog.md
```

以及 AGENTS 中：

> 每次文档或代码变动，必须在 docs/devlog.md 中留存痕迹

的规定。

原因：

Git history / PR / commit 本身已经记录工程变更；强制维护第二份流水账对 base template 的价值较低，而且与其他 base repository 的共同约定不一致。

**本次重构本身也不需要为了满足即将删除的旧 policy 再补一条 devlog。**

保留本文作为设计与决策记录即可。

---

## 17. 预期文件级变化

下面是计划，不要求实现 Agent机械遵守文件数量，但最终语义必须一致。

### 修改

- `README.md`
- `AGENTS.md`
- `xmake.lua`
- `.clangd`
- `.githooks/pre-commit`
- `.github/workflows/ci.yml`
- 可能：`.clang-tidy`（仅兼容目标 clang-tidy 所需的最小更新）
- 可能：`.clang-format`（仅兼容目标 clang-format 所需的最小更新）

### 新增

- `.editorconfig`
- 至少一个 `tests/unit/` 下的最小 doctest test source

### 删除

- `include/version.hpp`
- `docs/devlog.md`

### 保留

- `.gitattributes`
- `.gitignore`（如新行为需要少量补充可修改）
- `src/main.cpp`
- `tests/test_main.cpp`
- `LICENSE`
- xmake
- doctest

---

## 18. 明确非目标

实现 Agent **不要**在本轮顺手做以下事情：

- 创建 library target；
- 把 `main.cpp` 重构成复杂 application architecture；
- 引入 namespace/project-name 体系；
- 引入 logger；
- 引入 CLI parser；
- 引入 error handling library；
- 引入 benchmark；
- 引入 sanitizer CI；
- 引入 coverage；
- 引入 release workflow；
- 引入 package publishing；
- 引入 Docker；
- 引入 Nix；
- 引入 devcontainer；
- 引入 CMake；
- 增加 Windows/macOS CI；
- 增加 GCC CI matrix；
- 大幅扩展 clang-tidy checks；
- 重新设计 clang-format style；
- 引入 Makefile / justfile / task runner；
- 增加 pre-push hook；
- 自动修改用户全局 Git config。

本轮目标是“把 base 做干净”，不是“把 base 做大”。

---

## 19. 实施建议顺序

建议 Agent 按下面顺序实施，减少中间状态互相干扰：

1. 升级 C++23，简化 Clang toolchain/runtime 配置；
2. 清理 version metadata；
3. 增加最小 doctest test；
4. 重构 `xmake format` / `xmake check`；
5. 重构 staged-only pre-commit hook；
6. 清理 clangd suppression；
7. 增加 `.editorconfig`；
8. 更新 CI；
9. 重写 README；
10. 重写 AGENTS；
11. 删除 devlog；
12. 全量验证。

---

## 20. 验收标准

实现完成后至少验证以下内容。

### 20.1 Clean build

从干净配置开始：

```bash
xmake f -c -y --toolchain=clang
xmake
```

必须成功，且使用 C++23。

### 20.2 Run

```bash
xmake run app
```

必须成功。

### 20.3 Unit tests

```bash
xmake test
```

必须成功，并确认至少有一个 doctest test 实际被执行，而不只是成功启动一个空 runner。

### 20.4 Explicit format

人为制造一个可被 clang-format 修正的格式问题后：

```bash
xmake format
```

应修复它。

### 20.5 Non-mutating full check

在 clean repository 上：

```bash
xmake check
git status --short
```

`xmake check` 必须成功，且第二条命令没有因为 check 产生 tracked file modification。

### 20.6 Format failure

人为制造格式错误但不要执行 format：

```bash
xmake check
```

必须失败。

恢复后再继续测试。

### 20.7 Hook normal path

安装：

```bash
git config core.hooksPath .githooks
```

staged 一个格式正确的 C++ 修改，commit 应通过 hook。

### 20.8 Hook format failure

staged 一个格式错误的 C++ 修改：

- commit 应被 hook 阻止；
- working tree 不应被 hook 修改；
- index 不应被 hook重新 stage；
- 输出应说明 formatting validation failure。

### 20.9 Partial staging safety

这是本轮必须验证的 regression test。

构造同一 C++ 文件：

- hunk A staged；
- hunk B unstaged。

运行 hook/尝试 commit 后，必须确认：

- hook 不会把 B stage；
- hook 不会修改 B；
- index 内容保持用户原来的 staged snapshot；
- 若 A 本身格式正确，应只基于 staged snapshot 判断通过；
- 若 A 格式错误，应失败但仍不修改 index/worktree。

### 20.10 Missing clang-format

存在 staged C++ 文件时，让 hook 环境找不到 clang-format：

- hook 必须失败；
- 给出明确错误；
- 不 silent pass。

### 20.11 GCC sanity

本轮虽然 CI 不做 GCC matrix，但本地应至少做一次：

```bash
xmake f -c -y --toolchain=gcc
xmake
xmake test
xmake run app
```

如果目标环境有 GCC，则应成功。

完成后切回 Clang 做最终验证。

### 20.12 CI

push 后 GitHub Actions：

- quality check green；
- smoke green；
- 不依赖 libc++/lld/compiler-rt/libunwind 的强制配置；
- 不使用 `@latest` action；
- 顶层权限为 `contents: read`。

---

## 21. Agent 最终交付要求

实现完成后，Agent 的总结应至少报告：

1. 修改/新增/删除了哪些文件；
2. C++23 是否实际生效；
3. Clang 与 GCC 各自的验证结果；
4. `xmake format` 行为；
5. `xmake check` 是否确认 non-mutating；
6. doctest 实际执行的测试数量；
7. partial staging hook regression test 结果；
8. CI 结果和对应 run URL；
9. 是否存在与本文设计不同的实现选择，以及原因。

若实施过程中发现本文某项在当前 xmake / Clang / GitHub Actions 上存在客观不可行之处：

- 优先寻找满足同一语义的最小替代方案；
- 不要自行扩大工程范围；
- 在最终总结中明确记录偏差和原因。

---

## 22. 重构后的核心心智模型

重构完成后，使用者只需要记住：

```text
xmake                 # build
xmake run app         # run
xmake format          # explicitly modify formatting
xmake test            # unit tests
xmake check           # strict, non-mutating full validation
```

Git commit 之前：

```text
pre-commit
    = staged whitespace check
    + staged C/C++ format check
    + no mutation
    + no auto-stage
```

CI：

```text
checkout
    ↓
install toolchain
    ↓
xmake check
    ↓
xmake run app
```

这就是 `base-cpp v2` 的目标：**现代、严格、透明、轻量，并且每一种命令的副作用都清晰可预测。**

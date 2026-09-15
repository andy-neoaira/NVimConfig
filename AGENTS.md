# AGENTS

## 目的与协作

- 本文件供在仓库内工作的编码代理参考；所有对话尽量使用中文。
- 这是个人 Neovim Lua 配置，没有独立应用构建步骤。以实际代码和 `lazy-lock.json` 为依据，不把历史报告当作当前状态。
- 修改前查看 `git status --short` 和相关 diff，保留用户已有改动。审查请求先报告可复现的问题、位置和影响；没有证据时不要为凑数量推断缺陷。
- 只修改任务相关文件。不要未经询问批量改写文件或重写格式工具配置；先检查并报告现状。

## 环境与启动

- 当前配置要求 **Neovim 0.12+**，版本检查位于 `lua/config/init.lua`。
- 启动链路：`init.lua` → `require("config")` → leader 与基础选项 → lazy.nvim 引导 → `_G.GlobalUtil` → 插件 setup → 自动命令与通用键位 → 根目录初始化。
- lazy.nvim 缺失时会通过 Git 下载；普通启动不自动安装缺失插件、不检查插件更新，也不刷新 Mason 注册表或下载解析器。
- 显式安装入口：`:Lazy install`（完成后重启）、`:ToolsInstall`、`:TSInstallConfigured`。只有任务涉及安装或升级时才执行，检查配置不需要先升级依赖。
- `lazy-lock.json` 是插件版本依据；不要随普通修改运行 `:Lazy update`。恢复锁定版本使用 `:Lazy restore`。
- `dev = true` 的插件使用 `~/github` 下的本地开发目录；验证相关配置时检查本地插件是否存在。
- 搜索依赖 ripgrep、fd；解析器编译依赖 C 工具链和 tree-sitter CLI；外部格式化器、LSP 和调试工具按语言准备。

## 目录与职责

| 路径 | 职责 |
| --- | --- |
| `init.lua`、`lua/config/init.lua` | 入口、启动顺序与 lazy.nvim 配置 |
| `lua/config/options.lua` | 基础选项 |
| `lua/config/autocmds.lua` | 自动保存、文件事件、根缓存失效等 |
| `lua/config/keymaps.lua` | 通用键位；插件专属键位也分布在插件 spec 中 |
| `lua/plugins/*.lua` | 返回一个 lazy.nvim 插件 spec 或 spec 列表 |
| `lua/utils/init.lua` | 全局工具、元表懒加载及 Lazy 工具封装 |
| `lua/utils/lsp_options.lua`、`lsp_keymaps.lua` | 语言服务器选项与附加到缓冲区的 LSP 键位 |
| `lua/utils/buffer.lua`、`format.lua` | 自动保存与格式化入口、开关、优先级 |
| `lua/utils/root.lua`、`python.lua` | 项目根目录与 Python 解释器解析 |
| `lua/utils/input_method.lua`、`image.lua` | 输入法异步 IPC 与 Snacks 图片兼容适配 |
| `queries/` | JSON/JSON5 自定义 Treesitter 查询 |
| `tests/`、`scripts/check.sh` | 仓库自身的回归验证 |

`lua/config/` 是执行配置的模块，不要求返回插件 spec；`lua/utils/` 通常返回模块表。不要把插件 spec 的约定套用到所有 Lua 文件。

## 验证命令

在仓库根目录运行完整检查：

```sh
sh scripts/check.sh
```

前提：`nvim` 和 `stylua` 在 PATH 中，配置所需插件（包括 lazy.nvim）以及 JSON/JSON5 解析器已经安装。脚本依次执行：

1. `stylua --check lua tests init.lua`。
2. `tests/core.lua`：格式化开关、根目录边界、自动保存、未保存内容保护。
3. `tests/async.lua`：输入法时序、跨缓冲区诊断、图片异步结果失效。
4. `tests/integration.lua`：已安装插件的配置加载、键位、真实保存格式化、Markdown 开关和查询语法。
5. `git diff --check`。

脚本通过临时目录隔离 `XDG_STATE_HOME`、`XDG_CACHE_HOME`、`NVIM_LOG_FILE`，复用现有插件数据；结束后保留诊断目录。不要删除个人插件、会话或历史来处理测试失败。

只运行核心或异步测试时，可使用不加载个人配置的命令：

```sh
nvim --headless -u NONE -i NONE -l tests/core.lua
nvim --headless -u NONE -i NONE -l tests/async.lua
```

集成检查优先通过 `scripts/check.sh` 运行，保留状态隔离。注意验证边界：

- 核心与异步测试使用临时文件或桩；输入法相关断言仅在 macOS 执行。
- 集成测试禁用 Copilot 补全，不发送 AI 聊天请求；不能证明真实 AI、LSP、DAP 会话可用。
- 单独运行集成脚本时，若没有 StyLua，会跳过真实格式化断言；完整检查脚本则要求 StyLua 存在。
- 终端图片显示、真实 Hammerspoon 切换和各语言项目仍需按改动进行实际验收。
- 缺少依赖时报告缺失项和未验证范围，不把跳过检查描述为通过。

### 编辑项目的测试快捷键

这些快捷键用于 Neovim 中打开的 Python/Vitest 项目，不是本仓库的 Lua 回归入口：

- `lua/plugins/neotest.lua`：`<leader>tt` 运行光标附近测试，`<leader>tf` 运行文件，`<leader>tF` 运行工作目录下测试。
- `lua/plugins/dap.lua`：`<leader>td` 调试光标附近测试。
- `require("neotest").run.run_last()` 重跑上次测试；`run_last({ strategy = "dap" })` 是调试上次测试，不是筛选上次失败项。`<leader>tl` 当前被注释。
- 目标项目中可用 `pytest path/to/test_file.py::test_function_name -q` 或 `npx vitest -t "test name"`；本仓库没有对应的 pytest/Vitest 测试套件。

## 格式与代码约定

- Lua 遵循现有 StyLua 风格（通常为 Tab 缩进、双引号）。局部修改使用 `stylua path/to/changed.lua`，避免全仓库重排。保留有意设置的 `-- stylua: ignore`。
- 仓库当前没有专用 StyLua/Prettier 配置文件；不要为文档或小修复引入新的风格配置、依赖或锁文件。
- Markdown/JSON 等可使用已安装的 Prettier 格式化改动文件；`scripts/check.sh` 不检查 Markdown 排版。不把 `luacheck`、markdownlint 或未配置的 CI 当作现有必经流程。
- 模块表通常命名 `M`，变量和函数沿用所在模块的命名方式，优先下划线命名。使用 `local`，避免新增全局。
- 工具模块路径对应 require 名，例如 `lua/utils/python.lua` → `require("utils.python")`。新增工具沿用 `GlobalUtil` 的元表懒加载，不另建全局入口。
- 用 EmmyLua/LuaLS 注解描述参数和返回值；复杂逻辑写简短中文注释，解释职责、时序和边界。
- 稳定依赖可在模块顶部引入；懒加载插件应在 `opts`、`config`、事件或键位回调中 require，避免提前加载。插件副作用放入 lazy 生命周期回调。
- 可预期失败使用 `pcall` 和明确回退；通过 `GlobalUtil.info/warn/error` 或合适的 `vim.notify_once` 报告问题，不静默吞掉重要异常。
- 自动命令使用有名称且 `clear = true` 的分组；异步回调重新检查缓冲区有效性和状态，避免旧结果覆盖新操作，释放计时器等资源。

## 修改时需保持的行为

- **保存**：默认自动保存；`TextChanged` 合并为 200ms 后写入，`InsertLeave`、`FocusLost` 直接尝试保存。保护只读、特殊、未命名、URI 和未修改缓冲区，不用强制删除丢弃未保存内容。
- **开关**：`vim.g.autosave = false` 是自动保存总开关；自动格式化由缓冲区 `vim.b.autoformat` 优先覆盖全局 `vim.g.autoformat`，`nil` 表示继承。手动 `<leader>cf` 强制格式化。
- **格式化**：外部工具统一由 `lua/plugins/conform.lua` 调度，保存同步完成，工具不可用时回退 LSP；不要添加第二条保存格式化链路。
- **LSP/Treesitter**：沿用当前 `vim.lsp.config` / `vim.lsp.enable` 及 Treesitter FileType 配置，不直接粘贴旧版 setup API。工具安装与服务器启用保持分离。
- **根目录**：保留路径边界检查、缓冲区缓存失效与切换成功后才更新状态的约定；不要用任意字符串前缀判断目录包含关系。
- **Python**：测试和调试目标解释器复用 `utils.python.resolve`，按激活环境、项目 `.venv`/`venv`、系统解释器解析，不缓存跨项目结果。
- **可选集成**：Java LSP 默认关闭（`vim.g.java_lsp`）；输入法切换仅在 macOS、有 UI 且 `hs` 可执行时启用。图片兼容代码依赖 Snacks 内部实现，升级相关插件需检查该适配与异步回归。
- **凭据**：CopilotChat 的自定义提供方读取 `NVIM_AI_API_KEY`，不把密钥写入文件或日志。验证时不触发认证或发送聊天内容。

## 交付

- 功能修改执行相关回归，必要时补充能覆盖故障触发条件的测试；文档修改检查内容与源码一致、链接正确及 diff 空白错误。
- 新增依赖或更换工具时说明理由与回退方案。未经任务要求不自动提交、升级或发布。
- 汇报实际改动、检查结果和未覆盖范围。提交信息可用 `feat(...)`、`fix(...)`、`chore(...)` 等前缀，搭配简短中文说明。

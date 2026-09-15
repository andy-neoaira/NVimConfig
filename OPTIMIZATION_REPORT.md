# Neovim 配置完整审查与优化报告

## 结论与范围

本次已完成仓库配置的静态审查、针对性重构、关键边界中文注释、使用文档更新及自动化回归检查。基线为 Git 提交 `9328aa0`，验证环境为 macOS、Neovim 0.12.1，以及本机已安装的锁定插件。

审查覆盖入口、全部 config/plugins/utils Lua 文件、类型配置、三个 Treesitter 查询、锁文件、中英文 README 与仓库辅助说明。Git 内部文件、个人运行日志、缓存及代理运行数据不作为 Neovim 配置重构对象。审查不等于每个插件都需要改写；保留个人操作习惯和有效配置。

主要收益是消除潜在数据丢失、修复错误缓冲区和异步状态问题、统一格式化链路、明确启动与安装边界。没有做同条件前后性能基准，因此不提供启动提速百分比。

## 主要发现与修复

| 领域 | 原问题及影响 | 本次处理 |
| --- | --- | --- |
| 保存安全 | 自动保存可能作用于错误缓冲区，异常被吞；连续事件重复写入 | 新建 buffer 工具，绑定事件缓冲区、校验文件状态、200ms 防抖、阻止重入，写入失败提示 |
| 关闭安全 | 删除/会话处理存在强制丢弃未保存内容的路径 | 关闭回退使用非强制删除；取消关闭不再继续关窗；去掉会话保存/加载时强删特殊缓冲区的回调 |
| 根目录 | 字符串前缀误判 app/apple，根路径归一化为空，工作区更新和缓存失效不完整 | 使用目录边界和实时 workspace folders，修正文件起点、根路径和默认匹配，切换目录成功后才更新状态 |
| 格式化 | none-ls 与 Conform 重复，开关 false 被默认值覆盖，缺少完整保存入口 | Conform 统一外部格式化，LSP 回退；增加同步保存格式化；保留缓冲区显式覆盖；注册器幂等 |
| LSP | 大文件混合配置、Vue 层级错误、异步 setup 时序、能力检查参数不匹配 | 拆分服务器/键位/启动；修正 vue_ls、vtsls 请求及 capability 检查；同步配置后启用 |
| 启动 | 选项晚于插件初始化；日常启动夹杂安装任务；引导失败可能等待输入 | 基础选项提前；工具/解析器显式安装；引导失败清晰返回；缺插件提示安装 |
| 异步 | 输入法请求并行互相覆盖，lint 防抖读取当前窗口 | hs 请求串行且超时，保留最后待执行意图；lint 按缓冲区防抖并回到目标缓冲区 |
| 图片预览 | 实例重复、关闭后异步结果重新显示、切换状态不一致 | 集中兼容适配，实例复用，清理 placement，丢弃关闭后的结果；统一 Markdown 开关 |
| Python | 相对解释器路径及缓存选择在切换项目后失效 | 共享动态解释器解析；debugpy 宿主优先 Mason，目标 Python 随环境/项目解析 |
| 类型与诊断 | 全局类型伪定义、过宽诊断屏蔽、补全调试侵入内部实现 | 删除伪 API 定义、缩小屏蔽范围；事件式调试日志，不修改全局补全行为 |

Neovim 的强制 buffer 删除允许忽略未保存修改，因此安全关闭不能默认使用 force。[Neovim API 文档](https://neovim.io/doc/user/api.html)

LSP 能力检查使用当前缓冲区整数作为第二参数，并清理 detach/wipeout 缓存；格式化调用者传入的选项优先于默认值。[Neovim LSP 文档](https://neovim.io/doc/user/lsp.html)

## 重构后的职责

- `config/init.lua`：版本检查、基础选项、lazy 引导与插件初始化。
- `plugins/lsp.lua`：LSP 装配；`utils/lsp_options.lua`：服务器选项；`utils/lsp_keymaps.lua`：能力相关键位。
- `plugins/mason.lua`：工具声明与显式安装命令。
- `utils/buffer.lua`：安全自动保存与防抖。
- `utils/input_method.lua`：有界、串行的输入法 IPC。
- `utils/image.lua`：集中维护 Snacks 图片兼容逻辑。
- `utils/python.lua`：测试和调试共同使用的解释器选择。
- `utils/blink_debug.lua`：可选补全事件诊断。
- `tests/` 与 `scripts/check.sh`：可重复执行的回归检查。

原 LSP 插件文件由约 838 行拆为启动、选项、键位三个模块；目的在于隔离职责，并非以总行数减少作为正确性指标。对新增边界与复杂处理添加中文注释，统一 Lua 格式，保留必要类型注解。

## 行为变化与迁移

### 启动与工具安装

最低版本明确为 Neovim 0.12，与当前 Treesitter 主线要求一致；Treesitter 保持非懒加载。[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

首次使用按顺序执行 `:Lazy install`、重启、`:ToolsInstall`、`:TSInstallConfigured`。普通启动不自动安装缺失插件、刷新 Mason 注册表或下载解析器；lazy.nvim 本身缺失时仍进行引导。显式插件安装/更新的构建步骤仍可能访问网络。

Mason 自动启用范围限制为声明的服务器，避免本机其他已安装服务意外启动。工具清单补齐调试及已声明语言服务需要的项目，但本次没有执行安装或升级。Copilot 认证改为用户显式执行 `:Copilot auth`，自定义 Moonshot 配置保留。

### 保存和格式化

- 自动保存默认保留；无名、只读、不可修改、特殊缓冲区和 URI 不参与。
- TextChanged 合并为 200ms 后保存；InsertLeave、FocusLost 直接处理。重新进入当前缓冲区插入模式时，延迟保存交给后续退出插入事件。
- `vim.g.autosave = false` 是自动保存总关闭开关，`vim.b.autosave = false` 可单独禁用；自动格式化则以 `vim.b.autoformat` 显式值优先于全局设置，设为 nil 恢复继承。
- 保存格式化同步超时为 1000ms，默认手动格式化超时 3000ms；慢工具可能超时，需针对项目调整。
- JSON 优先使用第一个可用的 Prettier/jq，不重复执行两者；Prettier 使用插件内置项目查找。
- Markdown 保留 prettier、markdownlint-cli2、markdown-toc；TOC 有标记才运行，markdownlint-cli2 不再依赖已有诊断才运行。
- none-ls 重复格式化配置及对应两个锁文件条目移除。fish 诊断由 nvim-lint 负责。

### Java、Python 与图形功能

Java 仍默认关闭，启用需在加载配置前设置 `vim.g.java_lsp = true`。新配置按平台选择 jdtls 配置目录，以项目完整路径哈希隔离 workspace，明确 Maven 离线选项，避免与 Mason-LSP 重复启动。启动 jdtls 需要 JDK 21+，项目 JDK 可另外配置；路径建议使用绝对路径。[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)

旧 Java 配置把 `length` 当作行宽并单独传参，这是错误调用：Google Java Format 的 `--length` 是字符范围长度，需要与 `--offset` 配对。新配置提供 Google/AOSP 风格，不宣称支持任意行宽。[Google Java Format 参数说明](https://github.com/google/google-java-format/blob/master/core/src/main/java/com/google/googlejavaformat/java/UsageException.java)

Python 解释器依次检查有效的 VIRTUAL_ENV、项目 .venv/venv、PATH 中 python3/python。debugpy 宿主优先使用 Mason 独立环境；回退到项目解释器时，该环境仍需安装 debugpy。

图片适配仍依赖锁定版本 Snacks 的内部接口，并非完全消除私有 API。升级 Snacks 后应重点复测 Markdown 图片、Mermaid、滚动隐藏、重复开关。输入法只在 macOS、有 UI 且 hs 可用时运行，可全局关闭。

## 全量审查覆盖清单

以下按职责分组列出所有插件文件；“保留”表示已审查后未发现必须修改的配置问题，不代表已完成对应外部服务的端到端验收。

| 文件或分组 | 审查结论 / 处理 |
| --- | --- |
| init.lua；config/init、options、autocmds、keymaps | 入口保留；调整初始化顺序、保存/关闭事件、根缓存、当前诊断 API、remap 与图片开关 |
| utils/init、root、ui | 通知 timer/check 完整释放、延迟加载错误提示、VeryLazy 幂等；根目录和安全关闭修复 |
| utils/format、lsp、cmp、ts_queries；types.lua；.luarc.json | 修复开关/能力与回退；清理无调用者的 nvim-cmp 逻辑；公共 snippet.stop；查询隔离报错与类型清理 |
| plugins/lsp、conform、nvim-lint、nvim-jdtls | LSP 拆分、单一格式化入口、按缓冲区诊断、可选 Java 重建 |
| plugins/dap、neotest、venv-selector | 解释器共享；DAP 临时覆盖恢复；测试空结果防护；venv-selector 保留 |
| plugins/snacks、render-markdown、miniobsidian | 图片适配抽离；文件树移动键修正；根目录切换成功才刷新；保留 Vault 工作流 |
| plugins/treesitter、treesitter-context、nvim-ts-autotag | 显式解析器安装、按查询启用缩进、正确处理缺失环境变量；autotag 保留 |
| plugins/blink-cmp、lazydev、copilot-chat | lazydev source 启用、可选事件日志；Copilot 显式认证；聊天计时器防护；保留模型/提供方 |
| plugins/persistence、refactoring、nvim-filetype、noice | 移除强删会话缓冲区；按键/命令懒加载；明确 nui 依赖 |
| plugins/lualine、bufferline、colorscheme、edgy | 修复状态栏路径边界；其余布局、主题和缓冲区栏保留 |
| plugins/mini-icons、mini-pairs、mini-surround | 保留图标、自动配对和环绕配置 |
| plugins/flash、grug-far、gitsigns、todo-comments | 保留功能与键位；部分仅统一格式。Flash 原配置并非语法错误 |
| plugins/trouble、which-key、kitty-scrollback | 保留原工作流；部分仅格式化 |
| plugins/neo-tree | 原文件开头直接 return，整份配置不可达；删除死文件，不删除本地插件数据 |
| queries/json/context.scm、json5/context.scm、json5/folds.scm | 保留查询内容，使用已安装解析器验证三份语法 |
| lazy-lock.json | 仅移除 none-ls 两个条目，未更新其余插件版本 |
| README.md、README_EN.md、.github/copilot-instructions.md | 同步真实安装命令、目录结构、键位、开关和 Java 格式化说明 |
| AGENTS.md、.gitignore、LICENSE | 审查仓库约定与边界，保留 |
| 新增 utils 模块、mason.lua、tests、scripts | 按前述职责实现，并纳入格式和回归检查 |

## 验证结果

统一入口：

```sh
sh scripts/check.sh
```

| 检查 | 结果与覆盖 |
| --- | --- |
| StyLua | lua、tests、init.lua 全部通过格式检查 |
| 核心回归 | 24 项断言通过：格式注册/开关、根目录边界/缓存、目标缓冲区保存/防抖、非强制关闭 |
| 异步回归 | macOS 上 7 项断言通过：输入法串行与快速切换、lint 缓冲区绑定、图片实例/关闭/过期结果；非 macOS 跳过两项 IME 检查 |
| 实际插件集成 | 加载本机插件检查配置错误、命令/键位、Vue、格式注册器；真实 StyLua 写入格式化及禁用开关；真实 Markdown 开关与查询解析 |
| 正常启动 | 完整配置 headless 启动成功并正常退出 |
| 补丁卫生 | git diff --check 通过 |

检查使用临时状态、缓存、日志目录，保留日志便于排查，复用本机已有插件。集成检查禁用 Copilot 补全，不发送 AI 请求。断言数量不是覆盖率指标。

未验证：真实语言项目的完整 LSP 会话、Java 启动、实际断点调试/测试框架执行、AI 认证和响应、终端图形显示及真实 Hammerspoon 切换。异步测试中的图片和 IPC 部分使用 mock；实际插件加载通过不能替代这些交互验收。未执行全面 Lua 语言服务器类型诊断，也没有跨平台实机验证。

## 维护与回退

1. 更新插件前保存当前工作区 diff 和锁文件；更新后先运行检查脚本，再检查实际项目的编辑、格式化、调试和图片工作流。
2. 排障入口：`:Lazy`、`:Mason`、`:ConformInfo`、`:checkhealth vim.lsp`、`:checkhealth snacks`。
3. 如保存体验受慢格式化器影响，可先关闭当前缓冲区 autoformat；如需停用自动落盘，关闭 autosave。两个开关互不替代。
4. Java 默认关闭；图片适配和补全 snippet grammar 的兼容路径仍需随上游升级维护，部分 explorer 兼容调用仍采用保护性 pcall。
5. 所有修改保留在工作区，未创建提交、未升级插件、未删除用户插件/会话/笔记。删除的 neo-tree 配置可从基线提交取回；回退前先保存当前新增修改，避免覆盖后续工作。
6. 后续可增加真实项目夹具与 CI，但不应把本机 headless 通过解释成所有平台、所有插件功能均已验证。

# NVimConfig

个人 Neovim 配置，使用 lazy.nvim 管理插件，文件浏览和搜索统一使用 Snacks。

[English](README_EN.md)

## 功能概览

- Snacks 文件浏览、项目搜索、终端与 Git 操作。
- LSP、blink.cmp 补全、Conform 保存格式化与自动保存。
- neotest 测试、DAP 调试和 Python 虚拟环境选择。
- Markdown、图片与 Mermaid 预览，以及 Obsidian 笔记集成。
- Copilot 代码补全和通过 Moonshot API 提供的 CopilotChat。

## 环境要求

- Neovim **0.12+**：当前 Treesitter 和 LSP 配置以此为基线。
- Git、Nerd Font；解析器编译需要 C 工具链和 tree-sitter CLI，CopilotChat 构建需要 make。
- 搜索需要 ripgrep、fd；外部格式化和语言服务按需安装。
- Python 测试使用 pytest，JavaScript/TypeScript 测试使用 Vitest。
- 图片和 Mermaid 需要支持 Kitty 图形协议的终端及相应转换工具；用 `:checkhealth snacks` 检查。
- macOS 输入法切换可选安装 Hammerspoon 的 `hs` CLI。缺失或无图形界面时自动跳过。

## 安装与更新

先备份已有配置和数据，再将仓库放到 `~/.config/nvim`（自定义 XDG 路径时使用对应的 Neovim 配置目录），运行 `nvim`。保留已有的会话、历史和插件数据。

首次启动只自动引导 lazy.nvim；其余插件和外部工具由以下命令显式安装：

1. `:Lazy install`，完成后重启 Neovim。
2. `:ToolsInstall` 安装声明的语言服务、格式化器和调试工具。
3. `:TSInstallConfigured` 安装配置所需的 Treesitter 解析器。
4. 使用 Copilot 补全时执行 `:Copilot auth`。

日常启动不刷新 Mason 注册表、不自动下载解析器。更新插件用 `:Lazy update`；恢复锁定版本用 `:Lazy restore`。更新后运行检查脚本，特别留意图片兼容适配。

CopilotChat 使用 Moonshot API，通过环境变量 `NVIM_AI_API_KEY` 读取密钥；启动 Neovim 前确保该变量可用。聊天和 Copilot 补全使用各自的认证方式。提供方与模型配置见 [copilot-chat.lua](lua/plugins/copilot-chat.lua)。

## 编辑与自定义

### 自动保存与格式化

自动保存默认开启：退出插入模式、失去焦点时保存；普通模式连续编辑合并为 200ms 后保存。仅处理有名称、可写、已修改的普通文件，失败会提示。

保存时由 Conform 同步格式化，外部工具不可用时回退到支持格式化的 LSP。JSON 优先 Prettier，不可用时尝试 jq。

可在 `init.lua` 的 `require("config")` **之前**设置：

```lua
vim.g.autosave = false       -- 禁用全局自动保存
vim.g.autoformat = false     -- 禁用全局保存格式化
vim.g.input_method = false   -- 禁用输入法自动切换
vim.g.java_lsp = true        -- 可选：启用 Java LSP，默认关闭
vim.g.blink_diag = true      -- 可选：记录补全事件日志
```

单个缓冲区可设置 `vim.b.autosave = false` 或 `vim.b.autoformat = false`。自动保存的全局关闭是总开关；自动格式化则以缓冲区显式设置为先，设为 `nil` 恢复继承。手动格式化 `<leader>cf` 不受自动格式化开关限制。

### Java（可选）

Java 启用后需通过 `:Lazy install` 安装 nvim-jdtls，通过 `:ToolsInstall` 安装 jdtls，并准备 JDK 21+（通过 `JAVA_HOME` 或 PATH 提供）。项目可使用 `.nvim/java.json` 配置 JDK、Maven settings、离线模式及 Lombok。Java 格式化只支持 Google/AOSP 风格，例如：

```json
{ "google_java_format": { "aosp": false } }
```

设置 `aosp: true` 使用 AOSP 风格；该配置不提供任意行宽选项。完整配置见 [nvim-jdtls.lua](lua/plugins/nvim-jdtls.lua) 和 [conform.lua](lua/plugins/conform.lua)。

### Obsidian（可选）

Vault 配置位于 [miniobsidian.lua](lua/plugins/miniobsidian.lua)。使用前将 `default_vault` 改为自己的 Vault 名称；当前值是作者的个人设置。

## 常用按键

Leader 为空格。完整映射可用 `<leader>sk` 查看，也可按 Leader 查看 which-key 提示。

| 按键 | 功能 |
| --- | --- |
| `<leader>e` / `<C-e>` | Snacks 文件浏览器 |
| `<leader><space>` / `<leader>ff` | 智能找文件 / 文件搜索 |
| `<leader>sg` / `<leader>/` | 项目内容搜索 / 当前缓冲区行搜索 |
| `<leader>sr` | grug-far 搜索替换 |
| `<leader>h/j/k/l` | 分屏间移动 |
| `<S-h>` / `<S-l>` | 上一个 / 下一个缓冲区 |
| `<leader>bd` / `<leader>bo` | 关闭当前 / 其他缓冲区 |
| `<leader>cf` | 手动格式化 |
| `<leader>of` / `<leader>oF` | 全局 / 当前缓冲区自动格式化 |
| `<leader>om` | Markdown 与内联图片、Mermaid 预览开关 |
| `gd` / `gr` / `gi` / `<leader>cr` | 定义 / 引用 / 实现 / 重命名 |
| `<leader>ca` / `<leader>cd` | 代码操作 / 当前行诊断 |
| `]d` / `[d` | 下一条 / 上一条诊断 |
| `<leader>gg` | 项目根目录 Lazygit（需安装） |
| `<leader>gb` / `<leader>gl` | Git 分支 / 提交历史 |
| `<leader>tt` / `<leader>tf` / `<leader>td` | 光标附近测试 / 当前文件测试 / 调试光标附近测试 |
| `<leader>dc` / `<leader>db` | 启动或继续调试 / 切换断点 |
| `<leader>cv` | Python 虚拟环境选择 |
| `<leader>Ss` / `<leader>SS` | 恢复当前目录会话 / 选择会话 |
| `<leader>P` | 将当前文件所属项目设为工作目录 |
| `<C-/>` | 浮动终端 |
| `<C-a>` / `<leader>aa` | CopilotChat |
| `<leader>nn` / `<leader>nv` | 新建 Obsidian 笔记 / 切换 Vault |

文件树中 `y` 复制路径、`p` 粘贴；`x` 和 `m` 打开移动操作。删除使用回收站，并保护项目根目录。

## 配置结构

- `init.lua`：加载配置的入口。
- `lua/config/`：启动、基础选项、自动命令、通用键位。
- `lua/plugins/`：lazy.nvim 插件规格。
- `lua/utils/lsp_options.lua`：语言服务器选项；`lsp_keymaps.lua`：LSP 键位。
- `lua/utils/buffer.lua`、`input_method.lua`、`image.lua`、`python.lua`：保存、输入法、图片兼容和解释器解析。
- `queries/`：JSON/JSON5 自定义上下文与折叠查询。
- `tests/`、[scripts/check.sh](scripts/check.sh)：回归检查。
- [AGENTS.md](AGENTS.md)：代码维护与代理协作约定。

## 验证

在仓库根目录执行以下命令；需先安装配置所需插件、JSON/JSON5 解析器，并确保 `nvim` 和 `stylua` 在 PATH 中：

```sh
sh scripts/check.sh
```

脚本检查 Lua 格式、核心边界、异步回调、插件配置、真实保存格式化和查询语法。状态、缓存、日志使用临时目录，测试不发送 AI 请求。测试不能代替实际终端图片显示、真实调试会话或每一种语言项目的验收。

这是配置自身的回归检查；Python/Vitest 项目测试通过 neotest 或项目自己的测试命令运行。

## 故障排查

| 问题 | 检查入口 |
| --- | --- |
| 插件缺失或加载失败 | `:Lazy`；首次安装后重启 |
| 语言服务或工具不可用 | `:Mason`、`:checkhealth vim.lsp` |
| 保存未格式化 | `:ConformInfo`，检查全局及缓冲区 `autoformat` 开关 |
| 图片或 Mermaid 不显示 | `:checkhealth snacks`，检查终端协议与转换工具 |
| AI 认证失败 | 补全用 `:Copilot auth`；聊天检查 `NVIM_AI_API_KEY` |

## 许可

MIT。感谢 Neovim、LazyVim 及各插件作者。

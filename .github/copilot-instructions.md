# Neovim 配置 — Copilot 说明

## 项目简介

基于 **lazy.nvim** 的个人 Neovim 配置，纯 Lua 编写。涵盖 LSP、DAP、测试、格式化、Git 和 AI 助手。

## 架构

### 入口

`init.lua` 直接加载 `lua/config/`。

### 启动顺序（`lua/config/init.lua`）

1. 若缺失则自动引导安装 `lazy.nvim`
2. 设置 `mapleader = " "`（空格键）
3. 暴露 `_G.GlobalUtil = require("utils")` — 全局工具命名空间，全局可用
4. 基础 `config.options` 已在引导前加载；调用 `lazy.setup({ spec = { import = "plugins" } })` 导入插件规格
5. 加载 `config.autocmds`、`config.keymaps`（缺少基础插件时提示手动安装）
6. 通过 `GlobalUtil.root.reload_root_path()` 解析并存储项目根目录

### 插件文件（`lua/plugins/`）

每个文件必须**返回一个 lazy.nvim 插件 spec**（table 或 table 的 table）。lazy.nvim 自动发现该目录下所有文件 — 新增插件只需在此目录新建文件。

### 工具模块（`lua/utils/`）

`lua/utils/init.lua` 通过**元表懒加载**：访问 `GlobalUtil.lsp` 会自动 require `utils/lsp`，`GlobalUtil.root` 自动 require `utils/root`，以此类推。子模块首次访问后缓存。`GlobalUtil` 顶层还继承了 `lazy.core.util` 的所有内容。

全局可用的常用工具：
- `GlobalUtil.safe_keymap_set(mode, lhs, rhs, opts)` — 键映射包装器，跳过已被 lazy.nvim 处理的按键
- `GlobalUtil.icons` — 集中管理的图标表（诊断、Git、DAP、LSP 补全类型等）
- `GlobalUtil.memoize(fn)` — 函数结果缓存（记忆化）
- `GlobalUtil.get_pkg_path(pkg, path)` — 解析 Mason 包路径
- `GlobalUtil.root.root()` — 返回检测到的项目根目录
- `GlobalUtil.format.register(...)` — 向格式化子系统注册格式化器

## 关键约定

### 键映射

所有键映射通过 `GlobalUtil.safe_keymap_set`（在各键映射文件顶部别名为 `local map = GlobalUtil.safe_keymap_set`）。这样可避免与 lazy.nvim 自身的按键处理器冲突。

### 插件的 `opts` vs `config`

仅配置插件时优先使用 `opts = function() ... end`；只在需要命令式 setup 调用时才使用 `config = function(_, opts) ... end`。

### 格式化器注册

格式化器通过 `GlobalUtil.format.register(...)` 在 `GlobalUtil.on_very_lazy(...)` 回调内注册，确保所有插件加载完成后才可用。参考 `lua/plugins/conform.lua` 中的写法。

### Java 格式化的项目级配置

`google-java-format` 会读取项目根目录下的 `.nvim/java.json`：
```json
{ "google_java_format": { "aosp": false } }
```

### 代码注释语言

本配置的注释以**中文**为主（部分英文）。新增代码的行内注释应保持中文。

### 模糊查找 / 搜索

所有模糊查找（LSP 定义、引用、实现、文件搜索等）统一使用 `Snacks.picker`（来自 `folke/snacks.nvim`），不使用 Telescope。

### 类型注解

使用 EmmyLua / LuaLS 的 `---@` 注解。`lua/types.lua` 存放 `---@meta` 全局声明（如 `_G.GlobalUtil`），供 LuaLS 解析。新增全局变量需在此文件补充声明。

## 自定义入口

| 内容 | 位置 |
|------|------|
| 主题 | `lua/plugins/colorscheme.lua` |
| 编辑器选项 | `lua/config/options.lua` |
| 键映射 | `lua/config/keymaps.lua` |
| 新增插件 | `lua/plugins/` 下新建文件 |
| LSP 服务器 | `lua/utils/lsp_options.lua`（选项）、`lua/plugins/lsp.lua`（启动） |
| 格式化器 | `lua/plugins/conform.lua` |

工具安装统一通过 `:ToolsInstall`；解析器通过 `:TSInstallConfigured` 安装。普通启动不执行下载。
验证入口为 `sh scripts/check.sh`；完整重构依据见 `OPTIMIZATION_REPORT.md`。

## Neovim 内常用排查命令

| 问题 | 命令 |
|------|------|
| 插件未安装 | `:Lazy sync` |
| LSP 异常 | `:Mason`、`:LspInfo`、`:LspRestart` |
| 启动慢 | `:Lazy profile` |
| 格式化不生效 | `:ConformInfo` |

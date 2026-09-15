---@meta

-- 仅声明配置自有类型，Neovim API 类型由运行时和 lazydev 提供。
-- 不重新定义 vim.g 或 nvim_create_autocmd，避免类型文件意外覆盖真实 API。
---@class ConfigFeatureFlags
---@field autoformat? boolean 全局自动格式化开关
---@field autosave? boolean 全局自动保存开关
---@field input_method? boolean macOS 输入法自动切换开关
---@field java_lsp? boolean 可选 Java LSP 开关
---@field blink_diag? boolean 补全诊断事件日志开关

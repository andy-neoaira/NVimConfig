---@class utils.format
--- 代码格式化工具模块
--- 管理多个格式化器的注册、优先级和执行
---@overload fun(opts?: {force?:boolean})
local M = setmetatable({}, {
	__call = function(m, ...)
		return m.format(...)
	end,
})

---@class LazyFormatter
--- 格式化器配置
---@field name string 格式化器名称
---@field primary boolean|nil 是否为主格式化器（同一缓冲区只能有一个主格式化器）
---@field format fun(bufnr:number) 格式化函数
---@field sources fun(bufnr:number):string[] 获取可用源的函数
---@field priority number 优先级（数值越大优先级越高）

--- 已注册的格式化器列表
---@type LazyFormatter[]
M.formatters = {}

--- 注册格式化器
--- 格式化器按优先级降序排序
--- @param formatter LazyFormatter 格式化器配置
---
function M.register(formatter)
	-- 确保必要字段存在
	assert(formatter.name, "Formatter must have a name")
	assert(formatter.format, "Formatter must have a format function")
	assert(formatter.sources, "Formatter must have a sources function")

	formatter.priority = formatter.priority or 0
	-- 重载配置时替换同名注册项，避免一次保存执行多次格式化。
	for i, existing in ipairs(M.formatters) do
		if existing.name == formatter.name then
			table.remove(M.formatters, i)
			break
		end
	end

	M.formatters[#M.formatters + 1] = formatter

	-- 按优先级降序排序
	table.sort(M.formatters, function(a, b)
		return a.priority > b.priority
	end)
end

--- 获取格式化表达式
--- 用于 'formatexpr' 选项
--- @return any 返回格式化表达式的结果
function M.formatexpr()
	if GlobalUtil.has("conform.nvim") then
		return require("conform").formatexpr()
	end
	return vim.lsp.formatexpr({ timeout_ms = 3000 })
end

--- 解析格式化器状态
--- 确定哪些格式化器应该激活
--- @param buf number|nil 缓冲区编号，默认为当前缓冲区
--- @return (LazyFormatter|{active:boolean,resolved:string[]})[] 返回格式化器状态列表
---
function M.resolve(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local has_primary = false

	return vim.tbl_map(function(formatter)
		local sources = formatter.sources(buf)
		-- 格式化器激活条件：
		-- 1. 有可用的源
		-- 2. 不是主格式化器，或者是第一个主格式化器
		local active = #sources > 0 and (not formatter.primary or not has_primary)
		has_primary = has_primary or (active and formatter.primary) or false

		return setmetatable({
			active = active,
			resolved = sources,
		}, { __index = formatter })
	end, M.formatters)
end

--- 显示格式化器信息
--- 在浮动窗口中显示自动格式化状态和可用的格式化器
--- @param buf number|nil 缓冲区编号，默认为当前缓冲区
function M.info(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local global_enabled = vim.g.autoformat == nil or vim.g.autoformat
	local buffer_autoformat = vim.b[buf].autoformat
	local enabled = M.enabled(buf)

	local lines = {
		"# 状态",
		("- [%s] 全局 **%s**"):format(global_enabled and "x" or " ", global_enabled and "启用" or "禁用"),
		("- [%s] 缓冲区 **%s**"):format(
			enabled and "x" or " ",
			buffer_autoformat == nil and "继承" or buffer_autoformat and "启用" or "禁用"
		),
	}

	local has_formatter = false
	for _, formatter in ipairs(M.resolve(buf)) do
		if #formatter.resolved > 0 then
			has_formatter = true
			lines[#lines + 1] = "\n# " .. formatter.name .. (formatter.active and " ***(激活)***" or "")
			for _, line in ipairs(formatter.resolved) do
				lines[#lines + 1] = ("- [%s] **%s**"):format(formatter.active and "x" or " ", line)
			end
		end
	end

	if not has_formatter then
		lines[#lines + 1] = "\n***该缓冲区没有可用的格式化器。***"
	end

	GlobalUtil[enabled and "info" or "warn"](
		table.concat(lines, "\n"),
		{ title = "LazyFormat (" .. (enabled and "已启用" or "已禁用") .. ")" }
	)
end

--- 检查自动格式化是否启用
--- @param buf number|nil 缓冲区编号，默认为当前缓冲区
--- @return boolean 如果启用返回 true，否则返回 false
function M.enabled(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	local global_autoformat = vim.g.autoformat
	local buffer_autoformat = vim.b[buf].autoformat

	-- 优先使用缓冲区本地设置
	if buffer_autoformat ~= nil then
		return buffer_autoformat
	end

	-- 否则使用全局设置（默认为 true）
	return global_autoformat == nil or global_autoformat
end

--- 切换自动格式化状态
--- @param buf boolean|nil 是否仅切换当前缓冲区
function M.toggle(buf)
	local enabled = M.enabled()
	if not buf then
		enabled = vim.g.autoformat ~= false
	end
	M.enable(not enabled, buf)
end

--- 启用或禁用自动格式化
--- @param enable boolean|nil 是否启用，默认为 true
--- @param buf boolean|nil 是否仅影响当前缓冲区
---
--- 启用/禁用时若状态未变化则不提示，避免噪声
function M.enable(enable, buf)
	enable = enable == nil and true or enable
	-- 显式区分 nil 与 false，保留缓冲区覆盖设置。
	local prev = vim.g.autoformat
	if buf then
		prev = vim.b.autoformat
	end
	if prev == enable then
		return
	end
	if buf then
		vim.b.autoformat = enable
	else
		vim.g.autoformat = enable
	end
	M.info()
end

--- 格式化缓冲区
--- 使用激活的格式化器格式化当前缓冲区
--- @param opts table|nil 格式化选项
---   - force: 是否强制格式化（忽略自动格式化设置）
---   - buf: 缓冲区编号
---
function M.format(opts)
	opts = opts or {}
	local buf = opts.buf or vim.api.nvim_get_current_buf()

	-- 检查是否应该格式化
	if not ((opts and opts.force) or M.enabled(buf)) then
		return
	end

	local formatted = false

	-- 执行所有激活的格式化器
	for _, formatter in ipairs(M.resolve(buf)) do
		if formatter.active then
			formatted = true
			GlobalUtil.try(function()
				return formatter.format(buf)
			end, { msg = "格式化器 `" .. formatter.name .. "` 执行失败" })
		end
	end

	-- 如果是强制格式化但没有可用的格式化器，发出警告
	if not formatted and opts and opts.force then
		GlobalUtil.warn("没有可用的格式化器", { title = "LazyVim" })
	end
	-- 可通过 GlobalUtil.format.snacks_toggle() 绑定到状态栏或快捷键以快速切换
end

--- 创建 Snacks 切换开关
--- 用于在状态栏或命令中切换自动格式化
--- @param buf boolean|nil 是否仅影响当前缓冲区
--- @return any 返回 Snacks 切换对象
function M.snacks_toggle(buf)
	return Snacks.toggle({
		name = "自动格式化 (" .. (buf and "缓冲区" or "全局") .. ")",
		get = function()
			if not buf then
				return vim.g.autoformat == nil or vim.g.autoformat
			end
			return GlobalUtil.format.enabled()
		end,
		set = function(state)
			GlobalUtil.format.enable(state, buf)
		end,
	})
end

return M

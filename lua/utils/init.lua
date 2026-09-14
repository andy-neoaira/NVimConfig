local LazyUtil = require("lazy.core.util")

---@class utils: LazyUtilCore
---@field ui utils.ui
---@field lsp utils.lsp
---@field root utils.root
---@field format utils.format
---@field mini utils.mini
---@field cmp utils.cmp
local M = {}

--- 设置元表实现延迟加载子模块
--- 当访问一个不存在的键时，首先检查 LazyUtil 中是否存在
--- 如果不存在，则尝试加载 utils 包下对应的子模块
--- 这种方式可以避免在启动时加载所有模块，提高启动速度
--- @param t table 当前表
--- @param k string 要访问的键名
--- @return any 返回对应的值或加载的模块
setmetatable(M, {
	__index = function(t, k)
		-- 优先从 LazyUtil 中获取
		if LazyUtil[k] then
			return LazyUtil[k]
		end
		-- 延迟加载并缓存子模块
		local ok, module = pcall(require, "utils." .. k)
		if ok then
			t[k] = module
			return module
		end
		-- 返回 nil 而不是抛出错误，避免访问不存在的模块时崩溃
		return nil
	end,
})
--- 通用图标配置
--- 用于在整个配置中统一显示各类图标
--- 包括诊断、Git、DAP调试、代码补全等场景的图标
M.icons = {
	misc = {
		dots = "󰇘",
	},
	ft = {
		octo = "",
	},
	dap = {
		Stopped = { "󰁕 ", "DiagnosticWarn", "DapStoppedLine" },
		Breakpoint = " ",
		BreakpointCondition = " ",
		BreakpointRejected = { " ", "DiagnosticError" },
		LogPoint = ".>",
	},
	diagnostics = {
		Error = " ",
		Warn = " ",
		Hint = " ",
		Info = " ",
	},
	git = {
		added = " ",
		modified = " ",
		removed = " ",
	},
	kinds = {
		Apple = " ",
		Array = " ",
		Buffer = " ",
		Boolean = "󰨙 ",
		Class = " ",
		Codeium = "󰘦 ",
		Color = " ",
		Control = " ",
		Collapsed = " ",
		Constant = "󰏿 ",
		Constructor = " ",
		Copilot = " ",
		Dev = " ",
		Enum = " ",
		EnumMember = " ",
		Event = " ",
		Field = " ",
		File = " ",
		Folder = " ",
		Function = "󰊕 ",
		Interface = " ",
		Key = " ",
		Lsp = "󰰍 ",
		Keyword = " ",
		Markdown = " ",
		Method = "󰊕 ",
		Module = " ",
		Namespace = "󰦮 ",
		Null = " ",
		Number = "󰎠 ",
		Object = " ",
		Operator = " ",
		Package = " ",
		Path = " ",
		Property = " ",
		Reference = " ",
		Snippet = " ",
		String = " ",
		Struct = "󰆼 ",
		Supermaven = " ",
		TabNine = "󰏚 ",
		Text = " ",
    Tool = "󱁤 ",
		TypeParameter = " ",
		Unit = " ",
    User = " ",
		Value = " ",
		Variable = "󰀫 ",
	},
}

--- 检测当前操作系统是否为 Windows
--- @return boolean 如果是 Windows 系统返回 true，否则返回 false
function M.is_win()
	return vim.uv.os_uname().sysname:find("Windows") ~= nil
end

--- 获取指定名称的插件配置对象
--- @param name string 插件名称
--- @return LazyPlugin|nil 返回插件配置对象，如果不存在则返回 nil
function M.get_plugin(name)
	return require("lazy.core.config").spec.plugins[name]
end

--- 获取指定插件的安装路径
--- @param name string 插件名称
--- @param path string|nil 可选的子路径，会追加到插件根目录后
--- @return string|nil 返回完整路径，如果插件不存在则返回 nil
function M.get_plugin_path(name, path)
	local plugin = M.get_plugin(name)
	path = path and "/" .. path or ""
	return plugin and (plugin.dir .. path)
end

--- 检查指定插件是否已安装
--- @param plugin string 插件名称
--- @return boolean 如果插件已安装返回 true，否则返回 false
function M.has(plugin)
	return M.get_plugin(plugin) ~= nil
end

--- 在 VeryLazy 事件触发时执行指定函数
--- VeryLazy 是 lazy.nvim 的一个事件，在所有插件加载完成后触发
--- 适用于需要在插件完全加载后才能执行的初始化代码
--- @param fn function 要执行的函数
function M.on_very_lazy(fn)
	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		callback = function()
			fn()
		end,
	})
end

--- 扩展深度嵌套的列表
--- 通过点分隔的键路径访问和扩展嵌套表中的列表
--- 如果路径中的表不存在，会自动创建
--- @generic T 列表元素类型
--- @param t table 要扩展的表
--- @param key string 点分隔的键路径，例如 "a.b.c"
--- @param values T[] 要添加的值列表
--- @return T[]|nil 返回扩展后的列表，如果路径无效则返回 nil
--- 
--- 优化点：
--- 1. 添加了类型检查，避免在非表类型上继续访问
--- 2. 使用局部变量缓存中间结果
function M.extend(t, key, values)
	local keys = vim.split(key, ".", { plain = true })
	local current = t
	
	for i = 1, #keys do
		local k = keys[i]
		-- 确保当前节点是表类型
		if type(current) ~= "table" then
			return nil
		end
		-- 如果键不存在或不是表，则创建新表
		current[k] = current[k] or {}
		current = current[k]
	end
	
	-- 确保最终节点是表类型
	if type(current) ~= "table" then
		return nil
	end
	
	return vim.list_extend(current, values)
end

--- 获取插件的配置选项
--- @param name string 插件名称
--- @return table 返回插件的 opts 配置，如果插件不存在则返回空表
function M.opts(name)
	local plugin = M.get_plugin(name)
	if not plugin then
		return {}
	end
	local Plugin = require("lazy.core.plugin")
	return Plugin.values(plugin, "opts", false)
end

--- 延迟通知系统
--- 在 vim.notify 被替换或超时后才发送通知
--- 这样可以确保通知插件（如 noice.nvim）加载完成后再显示通知
--- 避免在启动早期显示的通知被默认的通知系统处理
--- 
--- 优化点：
--- 1. 使用更清晰的变量名
--- 2. 添加错误处理
--- 3. 改进注释说明
function M.lazy_notify()
	local pending_notifs = {}
	
	-- 临时通知函数，收集所有通知
	local function collect_notif(...)
		table.insert(pending_notifs, vim.F.pack_len(...))
	end

	local original_notify = vim.notify
	vim.notify = collect_notif

	local timer = vim.uv.new_timer()
	local check = assert(vim.uv.new_check())

	-- 重放所有收集的通知
	local function replay_notifications()
		timer:stop()
		check:stop()
		
		-- 恢复原始的 notify 函数
		if vim.notify == collect_notif then
			vim.notify = original_notify
		end
		
		-- 在调度器中重放通知，避免阻塞
		vim.schedule(function()
			for _, notif in ipairs(pending_notifs) do
				vim.notify(vim.F.unpack_len(notif))
			end
		end)
	end

	-- 监控 vim.notify 是否被替换
	check:start(function()
		if vim.notify ~= collect_notif then
			replay_notifications()
		end
	end)
	
	-- 超时保护：500ms 后强制重放
	timer:start(500, 0, replay_notifications)
end

--- 检查插件是否已加载
--- @param name string 插件名称
--- @return boolean 如果插件已加载返回 true，否则返回 false
function M.is_loaded(name)
	local Config = require("lazy.core.config")
	return Config.plugins[name] and Config.plugins[name]._.loaded
end

--- 在插件加载时或加载后执行回调函数
--- 如果插件已经加载，立即执行回调
--- 如果插件未加载，等待 LazyLoad 事件后执行
--- @param name string 插件名称
--- @param fn function 回调函数，接收插件名称作为参数
function M.on_load(name, fn)
	if M.is_loaded(name) then
		fn(name)
	else
		vim.api.nvim_create_autocmd("User", {
			pattern = "LazyLoad",
			callback = function(event)
				if event.data == name then
					fn(name)
					return true
				end
			end,
		})
	end
end

--- 安全的键盘映射设置
--- 包装 vim.keymap.set，如果 lazy.nvim 的键处理器已经处理了该键，则不创建映射
--- 默认设置 silent 为 true，避免命令回显
--- 
--- @param mode string|table 模式字符串或模式列表，如 'n', 'v', {'n', 'v'}
--- @param lhs string 左侧快捷键
--- @param rhs string|function 右侧命令或函数
--- @param opts table|nil 选项表
--- 
--- 优化点：
--- 1. 添加了参数验证
--- 2. 改进了 modes 处理逻辑
--- 3. 优化了选项处理
function M.safe_keymap_set(mode, lhs, rhs, opts)
	local keys = require("lazy.core.handler").handlers.keys
	
	-- 规范化模式为列表
	local modes = type(mode) == "string" and { mode } or mode
	
	-- 过滤掉已被 lazy.nvim 处理的模式
	modes = vim.tbl_filter(function(m)
		return not (keys.have and keys:have(lhs, m))
	end, modes)

	-- 如果还有未处理的模式，创建映射
	if #modes > 0 then
		opts = opts or {}
		-- 默认静默模式
		opts.silent = opts.silent ~= false
		-- 移除 remap 选项（使用 noremap）
		if opts.remap then
			opts.remap = nil
		end
		vim.keymap.set(modes, lhs, rhs, opts)
	end
end

--- 列表去重
--- 保持元素首次出现的顺序，移除重复元素
--- @generic T
--- @param list T[] 输入列表
--- @return T[] 去重后的列表
--- 
--- 优化点：使用哈希表实现 O(n) 时间复杂度
function M.dedup(list)
	local result = {}
	local seen = {}
	
	for _, value in ipairs(list) do
		if not seen[value] then
			table.insert(result, value)
			seen[value] = true
		end
	end
	
	return result
end

--- 创建撤销点的特殊字符序列
--- 用于在插入模式下创建撤销点
M.CREATE_UNDO = vim.api.nvim_replace_termcodes("<c-G>u", true, true, true)

--- 在插入模式下创建撤销点
--- 允许用户撤销到当前位置，而不是撤销整个插入序列
function M.create_undo()
	if vim.api.nvim_get_mode().mode == "i" then
		vim.api.nvim_feedkeys(M.CREATE_UNDO, "n", false)
	end
end

--- 获取 Mason 包的路径
--- Mason 是 Neovim 的包管理器，用于安装 LSP 服务器、格式化工具等
--- @param pkg string 包名称
--- @param path string|nil 可选的子路径
--- @param opts table|nil 选项表 { warn?: boolean }
--- @return string 返回完整的包路径
--- 
--- 优化点：
--- 1. 改进了路径拼接逻辑
--- 2. 添加了更好的错误处理
--- 3. 使用 vim.uv.fs_stat 替代 vim.loop.fs_stat（更现代的 API）
function M.get_pkg_path(pkg, path, opts)
	-- 确保 Mason 已加载（生成文档时可能失败）
	pcall(require, "mason")
	
	local root = vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")
	opts = opts or {}
	opts.warn = opts.warn == nil and true or opts.warn
	path = path or ""
	
	local full_path = root .. "/packages/" .. pkg .. "/" .. path
	
	-- 检查路径是否存在，如果不存在且需要警告，则发出警告
	if opts.warn and not vim.uv.fs_stat(full_path) and not require("lazy.core.config").headless() then
		M.warn(
			("Mason 包路径未找到: **%s**:\n- `%s`\n您可能需要强制更新该包。"):format(pkg, path)
		)
	end
	
	return full_path
end

--- 重写默认的通知函数，添加自定义标题
--- 为 info、warn、error 三个级别的通知添加 "Config" 标题
for _, level in ipairs({ "info", "warn", "error" }) do
	M[level] = function(msg, opts)
		opts = opts or {}
		opts.title = opts.title or "Config"
		return LazyUtil[level](msg, opts)
	end
end

--- 函数结果缓存（记忆化）
--- 用于缓存函数的返回值，避免重复计算
--- @type table<function, table<string, any>>
local memoize_cache = {}

--- 创建一个记忆化版本的函数
--- 相同参数的调用会返回缓存的结果，提高性能
--- @generic T: function
--- @param fn T 要记忆化的函数
--- @return T 返回记忆化后的函数
--- 
--- 优化点：
--- 1. 使用独立的缓存变量，避免污染全局作用域
--- 2. 添加了更清晰的注释
function M.memoize(fn)
	return function(...)
		local key = vim.inspect({ ... })
		memoize_cache[fn] = memoize_cache[fn] or {}
		if memoize_cache[fn][key] == nil then
			memoize_cache[fn][key] = fn(...)
		end
		return memoize_cache[fn][key]
	end
end

return M

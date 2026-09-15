-- 当前 Treesitter 与 LSP 配置以 Neovim 0.12 为最低版本。
if vim.fn.has("nvim-0.12") == 0 then
	vim.api.nvim_echo({ { "此配置需要 Neovim 0.12 或更高版本", "ErrorMsg" } }, true, {})
	return {}
end

-- leader 与基础选项必须先于插件初始化，否则插件会缓存错误的默认值。
vim.g.mapleader = " "
vim.g.maplocalleader = " "
require("config.options")

-- 下载插件管理器
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
		}, true, {})
		return {}
	end
end
--添加rtp
vim.opt.rtp:prepend(lazypath)

--全局工具
_G.GlobalUtil = require("utils")
GlobalUtil.lazy_notify()
--启动插件
require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},

	-- 本地开发插件目录（dev = true 的插件从此路径加载）
	dev = { path = "~/github" },
	-- 不要在启动时自动安装缺失插件，避免网络握手导致卡顿
	install = { missing = false, colorscheme = { "tokyonight", "habamax" } },
	checker = {
		enabled = false, -- [强烈建议] 关闭启动自动检查更新。需要更新时手动运行 :Lazy check
		notify = false, -- 即使开启检查，也不要弹出通知窗口
		frequency = 3600, -- 如果开启，每小时检查一次即可
	},
	change_detection = {
		notify = false, -- 当你修改配置文件时，不要在右下角弹窗提醒
	},
	git = {
		-- 增加超时时间到 2 分钟，防止下载大插件（如 Copilot）时因为短暂波动被断开
		timeout = 120,
		-- 使用 partial clone 减少对象下载；lazy.nvim 不支持 depth 选项。
		filter = true,
	},
	concurrency = 4, -- 限制安装/更新任务并发，减少网络与磁盘竞争。
	ui = {
		-- 界面优化
		border = "rounded",
		wrap = true, -- 如果报错信息太长，自动换行显示，方便查错
	},
	performance = {
		rtp = {
			-- disable some rtp plugins
			disabled_plugins = {
				"gzip",
				-- "matchit",
				-- "matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
--加载自动命令
require("config.autocmds")
--加载键盘映射
-- 首次部署仍可打开 Lazy 安装界面，避免缺少 Snacks 时键位初始化报错。
if _G.Snacks then
	require("config.keymaps")
else
	GlobalUtil.warn("基础插件尚未安装，请执行 :Lazy install，完成后重启 Neovim")
end
--获取打开的参数
local path = vim.fn.getcwd()
-- 遍历参数列表
--[[@diagnostic disable-next-line: param-type-mismatch]]
for _, arg in ipairs(vim.fn.argv()) do
	if arg == "." then
		break
	end
	-- 使用 vim.uv.fs_stat 函数检查是否是目录
	local stat = vim.uv.fs_stat(arg)
	if stat and stat.type == "directory" then
		if string.sub(arg, 1, 1) ~= "/" then
			path = path .. "/" .. arg
		else
			path = arg
		end
		break
	end
end
GlobalUtil.root.reload_root_path(path)

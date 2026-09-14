-- 下载插件管理器
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
--添加rtp
vim.opt.rtp:prepend(lazypath)

--设置leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--全局工具
_G.GlobalUtil = require("utils")
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
		-- 强制开启浅克隆，极大地减少下载体积
		depth = 1,
		-- 尝试使用 https 协议，通常比 ssh 在代理环境下更稳定
		filter = true,
	},
	concurrency = 15, -- [关键] 限制同时下载的数量，2 个最稳，不会挤死带宽
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
--延迟通知
GlobalUtil.lazy_notify()
--加载通用设置
require("config.options")
--加载自动命令
require("config.autocmds")
--加载键盘映射
require("config.keymaps")
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

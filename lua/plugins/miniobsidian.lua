return {
	{
		"andy-neoaira/miniobsidian.nvim",
		-- dev = true, -- 从 ~/github/miniobsidian.nvim 加载本地源码
		lazy = true,
		ft = "markdown",
		cmd = {
			"ObsidianNew",
			"ObsidianNewHere",
			"ObsidianSwitch",
			"ObsidianSearch",
			"ObsidianBacklinks",
			"ObsidianMove",
			"ObsidianRename",
			"ObsidianSwitchVault",
			"ObsidianTemplate",
			"ObsidianNewTemplate",
			"ObsidianPasteImg",
			"ObsidianToday",
			"ObsidianSetup",
		},
		keys = {
			-- 全局操作（无需在 vault 内，keys 触发保证任意时刻可用）
			{
				"<leader>nn",
				function()
					require("miniobsidian.note").new_note()
				end,
				desc = "Obsidian: 新建笔记",
			},
			{
				"<leader>nN",
				function()
					require("miniobsidian.note").new_note(nil, { switch_root = true })
				end,
				desc = "Obsidian: 新建笔记（切换根目录）",
			},
			{
				"<leader>na",
				function()
					require("miniobsidian.note").new_note_here()
				end,
				desc = "Obsidian: 在文件树目录新建笔记",
			},
			{
				"<leader>no",
				function()
					require("miniobsidian.note").quick_switch()
				end,
				desc = "Obsidian: 快速切换",
			},
			{
				"<leader>ns",
				function()
					require("miniobsidian.note").search()
				end,
				desc = "Obsidian: 搜索 Vault",
			},
			{
				"<leader>nS",
				function()
					require("miniobsidian.note").search(vim.fn.expand("<cword>"))
				end,
				desc = "Obsidian: 搜索当前词",
			},
			{
				"<leader>nb",
				function()
					require("miniobsidian.note").backlinks()
				end,
				desc = "Obsidian: 当前笔记的反向链接",
				ft = "markdown",
			},
			{
				"<leader>nv",
				function()
					require("miniobsidian.vault").pick_and_switch()
				end,
				desc = "Obsidian: 切换 Vault",
			},
			{
				"<leader>nd",
				function()
					require("miniobsidian.daily").open_today()
				end,
				desc = "Obsidian: 创建日记",
			},
			{
				"<leader>nD",
				function()
					require("miniobsidian.daily").open_today({ switch_root = true })
				end,
				desc = "Obsidian: 创建日记（切换根目录）",
			},
			{
				"<leader>nT",
				function()
					require("miniobsidian.template").new_template()
				end,
				desc = "Obsidian: 创建模板",
			},
			-- Markdown 文件专用（ft 限定为 buffer-local keymap）
			{
				"<leader>nt",
				function()
					require("miniobsidian.template").insert()
				end,
				desc = "Obsidian: 插入模板",
				ft = "markdown",
			},
			{
				"<leader>np",
				function()
					require("miniobsidian.image").paste_file()
				end,
				desc = "Obsidian: 粘贴附件",
				ft = "markdown",
			},
			{
				"<leader>nl",
				function()
					require("miniobsidian.checkbox").clear()
				end,
				desc = "Obsidian: 恢复列表项",
				ft = "markdown",
			},
			{
				"<leader>nm",
				function()
					require("miniobsidian.note").move()
				end,
				desc = "Obsidian: 移动笔记",
			},
			{
				"<leader>nr",
				function()
					require("miniobsidian.note").rename()
				end,
				desc = "Obsidian: 重命名笔记",
			},

			-- <CR>：wiki link 内跳转（vault 内查找，找不到提示创建），否则切换 checkbox
			{
				"<CR>",
				function()
					require("miniobsidian.link").follow_link_or_toggle()
				end,
				desc = "Obsidian: 跟随 Wiki Link / 切换 Checkbox",
				ft = "markdown",
			},
		},
		config = function()
			-- 切换 Obsidian vault 根目录并刷新 explorer
			local function switch_obsidian_root(vault_path)
				GlobalUtil.root.reload_root_path(vault_path)
				GlobalUtil.root.refresh_explorer(vault_path)
				GlobalUtil.info("根目录已切换至: " .. vim.fn.fnamemodify(vault_path, ":~"), { title = "Obsidian Root" })
			end

			require("miniobsidian").setup({
				-- 零配置测试：vaults_parent 留空，auto_discover 自动从 Obsidian 官方配置发现 vault
				-- vaults_parent = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents",
				default_vault = "AndyObsidian",
				notes_subdir = "",
				checkbox_states = { " ", "/", "x" },
				on_vault_switch = function(_, path)
					switch_obsidian_root(path)
				end,
				after_note_open = function(_, opts)
					if opts and opts.switch_root then
						switch_obsidian_root(require("miniobsidian").config.vault_path)
					end
				end,
			})
		end,
	},

	-- blink.cmp 补全源：
	--   1. [[ 触发 → vault 内所有笔记链接补全
	--   2. -[ / *[ 触发 → checkbox 补全
	{
		"saghen/blink.cmp",
		optional = true,
		opts = function(_, opts)
			opts.sources = opts.sources or {}
			opts.sources.default = vim.list_extend(opts.sources.default or {}, { "miniobsidian" })
			opts.sources.providers = vim.tbl_deep_extend("force", opts.sources.providers or {}, {
				miniobsidian = {
					name = "MiniObsidian",
					module = "miniobsidian.completion",
					score_offset = 50, -- 高于 buffer/snippets，确保 [[ 时笔记候选靠前
					-- 触发字符由 source 内的 get_trigger_characters() 方法声明，
					-- provider spec 中不支持 trigger_characters 字段（blink.cmp 会报 warning）
				},
			})
			return opts
		end,
	},
}

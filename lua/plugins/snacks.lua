return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		---@type snacks.Config
		opts = {
			indent = { enabled = true },
			bigfile = { enabled = true },
			lazygit = { enabled = true },
			image = {
				-- 文档内内联渲染（markdown/html/tsx 等）
				doc = {
					enabled = true,
					inline = true,
					float = true,
					-- 内联图表覆盖源码；进入插入模式编辑对应区域时 Snacks 会暂时显示源码。
					conceal = function(lang, image_type)
						return lang == "mermaid" or image_type == "math"
					end,
					-- 增大尺寸以适配 Mermaid 图表（终端 174×46 格），原值 80/40 太小
					max_width = 140,
					max_height = 55,
				},
				-- ![[image.png]] Obsidian wikilink 格式路径解析
				-- 用闭包延迟 require，避免 snacks spec 解析时提前加载 miniobsidian.image
				resolve = function(ctx, src)
					return require("miniobsidian.image").resolve_for_snacks(ctx, src)
				end,
			},
			styles = {
				snacks_image = {
					relative = "cursor",
					focusable = false,
				},
			},
			notifier = {
				enabled = true,
				timeout = 3000,
			},
			explorer = {
				enabled = true,
				replace_netrw = true, -- 打开目录时由 Snacks 接管 netrw。
				trash = true, -- Use the system trash when deleting files
			},
			picker = {
				prompt = GlobalUtil.icons.kinds.Apple,
				enabled = true,
				ui_select = true,
				actions = {
					custom_noop = function() end,
					-- 复制文件完整路径到系统剪贴板
					custom_copy_path = function(picker)
						local selected = picker:selected({ fallback = true })
						local target = selected and selected[1]
						if not target or not target.file then
							return
						end
						vim.fn.setreg("+", target.file, "c")
						vim.notify("已复制路径: " .. target.file, vim.log.levels.INFO, { title = "explorer" })
					end,
					-- 粘贴单个文件时，如果目标目录已有同名文件，则先让用户输入新的文件名
					custom_explorer_paste = function(picker)
						local register = vim.v.register or "+"
						local files = vim.split(vim.fn.getreg(register) or "", "\n", { plain = true })
						files = vim.tbl_filter(function(file)
							return file ~= "" and vim.fn.filereadable(file) == 1
						end, files)

						-- 空寄存器和多文件粘贴继续交给 Snacks，保持其原有提示与批量行为
						if #files ~= 1 then
							picker:action("explorer_paste")
							return
						end

						local source = files[1]
						local dir = picker:dir()
						local filename = vim.fn.fnamemodify(source, ":t")
						local target = vim.fs.normalize(dir .. "/" .. filename)

						if not vim.uv.fs_stat(target) then
							picker:action("explorer_paste")
							return
						end

						local function prompt_new_name()
							Snacks.input({
								prompt = "复制文件为",
								default = filename,
								completion = "file",
							}, function(value)
								value = value and vim.trim(value) or ""
								if value == "" then
									return
								end

								local destination = vim.fs.normalize(dir .. "/" .. value)
								if vim.fs.dirname(destination) ~= vim.fs.normalize(dir) then
									Snacks.notify.warn("这里只能输入当前目录中的文件名")
									vim.schedule(prompt_new_name)
									return
								end
								if vim.uv.fs_stat(destination) then
									Snacks.notify.warn(
										"文件已存在，请输入新的文件名：\n- `" .. destination .. "`"
									)
									vim.schedule(prompt_new_name)
									return
								end

								Snacks.picker.util.copy_path(source, destination)
								picker:action("explorer_update")
							end)
						end

						prompt_new_name()
					end,
					-- 删除文件/文件夹，但禁止删除当前项目根目录
					custom_explorer_del = function(picker, item)
						local selected = picker:selected({ fallback = true })
						if not selected or #selected == 0 then
							return
						end
						local root = GlobalUtil.root.root()
						for _, target in ipairs(selected) do
							local target_path = target.file
							if target_path then
								target_path = GlobalUtil.root.realpath(target_path) or target_path
								if root and target_path == root then
									vim.notify(
										"不能删除当前项目根目录: " .. vim.fn.fnamemodify(root, ":~"),
										vim.log.levels.WARN,
										{ title = "explorer" }
									)
									return
								end
							end
						end
						picker:action("explorer_del")
					end,
					-- 导航上级目录并同步项目根目录
					-- 注意\uff1a必须用 picker:action() 调用内置动作，不能直接 require snacks 内部模块
					custom_explorer_up = function(picker, item)
						picker:action("explorer_up")
						vim.schedule(function()
							local cwd = vim.uv.cwd()
							if cwd then
								GlobalUtil.root.reload_root_path(cwd)
							end
						end)
					end,
				},
				win = {
					input = {
						keys = {
							["<c-a>"] = { "custom_noop", mode = { "n", "i" } }, -- 禁用全选
							["<c-b>"] = { "preview_scroll_up", mode = { "i", "n" } },
							["<c-f>"] = { "preview_scroll_down", mode = { "i", "n" } },
						},
					},
					list = {
						keys = {
							["<c-a>"] = "custom_noop", -- 禁用全选
						},
					},
				},
				sources = {
					ui_select = {
						win = {
							list = { number = false, relativenumber = false },
						},
					},
					recent = {
						filter = {
							-- v:oldfiles 可能包含通过 `nvim .` 或项目切换打开过的目录。
							-- Snacks 只检查路径是否存在，目录等于 cwd 时会被格式化成空白项。
							filter = function(item)
								return item.file ~= nil and vim.fn.filereadable(item.file) == 1
							end,
						},
					},
					files = {
						ignored = true, -- 默认显示 gitignore 文件
						hidden = true, -- 默认显示 gitignore 文件
						-- 黑名单：过滤常见二进制/编译产物/字体/媒体/压缩包等
						exclude = {
							".git",
							"node_modules",
							".venv",
							"*.class",
							"*.jar",
							"*.war",
							"*.ear",
							"*.o",
							"*.obj",
							"*.a",
							"*.lib",
							"*.so",
							"*.dylib",
							"*.dll",
							"*.exe",
							"*.pdb",
							"*.dSYM",
							"*.woff",
							"*.woff2",
							"*.ttf",
							"*.otf",
							"*.eot",
							"*.pdf",
							"*.zip",
							"*.tar",
							"*.gz",
							"*.bz2",
							"*.xz",
							"*.7z",
							"*.rar",
							"*.mp3",
							"*.mp4",
							"*.avi",
							"*.mkv",
							"*.mov",
							"*.flv",
							"*.webm",
							"*.doc",
							"*.docx",
							"*.xls",
							"*.xlsx",
							"*.ppt",
							"*.pptx",
							"*.deb",
							"*.rpm",
							"*.dmg",
							"*.pkg",
							"*.msi",
							"*.AppImage",
							"*.wasm",
							"*.min.js",
							"*.min.css",
						},
					},
					explorer = {
						ignored = true, -- 默认显示 gitignore 文件
						win = {
							list = {
								keys = {
									-- ESC 在 list 窗口中禁用（防止关闭 explorer）
									["<Esc>"] = false,
									-- ── 导航 ──────────────────────────────────────────
									["<BS>"] = "custom_explorer_up", -- 退回上级目录（同步根目录）
									["<CR>"] = "explorer_focus", -- 进入目录并设为 cwd（方案 B）
									["<2-LeftMouse>"] = "confirm", -- 双击打开文件
									["o"] = "confirm", -- 打开文件
									["l"] = "confirm", -- 打开文件（同 o）
									["h"] = "explorer_close", -- 折叠目录
									["s"] = "edit_split", -- 水平分割打开
									["v"] = "edit_vsplit", -- 垂直分割打开
									["O"] = "explorer_open", -- 用系统应用打开
									-- ── 搜索 / 过滤 ───────────────────────────────────
									["/"] = "focus_input", -- 聚焦顶部搜索框进行实时过滤（同 vim / 搜索习惯）
									-- ── 文件操作 ──────────────────────────────────────
									-- 新建：输入名称后按 <CR>；以 / 结尾自动创建目录
									["a"] = "explorer_add", -- 新建文件（名称末尾加 / 则建目录）
									["A"] = "explorer_add", -- 同上（保留 neo-tree 肌肉记忆）
									["d"] = "custom_explorer_del", -- 移入回收站（禁止删除项目根目录）
									["r"] = "explorer_rename", -- 重命名
									["y"] = { "explorer_yank", mode = { "n", "x" } }, -- 复制到剪贴板
									["Y"] = "custom_copy_path", -- 复制完整路径到系统剪贴板
									["x"] = "explorer_move", -- 移动文件；原 explorer_yank 实际只复制路径。
									["p"] = "custom_explorer_paste", -- 粘贴；同名冲突时提示重命名
									["c"] = "explorer_copy", -- 复制文件
									["m"] = "explorer_move", -- 移动文件
									-- ── 视图 ──────────────────────────────────────────
									["z"] = "explorer_close_all", -- 折叠所有目录
									["Z"] = "explorer_close_all",
									["R"] = "explorer_update", -- 刷新
									["u"] = "explorer_update",
									["<tab>"] = "toggle_preview", -- 切换预览
									["P"] = "toggle_preview",
									["<C-f>"] = { "preview_scroll_down", mode = { "n", "x" } },
									["<C-b>"] = { "preview_scroll_up", mode = { "n", "x" } },
									["I"] = "toggle_ignored", -- 切换显示 gitignore 文件
									["."] = "toggle_hidden", -- 切换显示隐藏文件
									-- ── 其他 ──────────────────────────────────────────
									["<c-o>"] = "explorer_open", -- 系统应用打开（备用）
									["<c-c>"] = "tcd", -- 设置 tab 工作目录
									["<leader>/"] = "picker_grep", -- 在当前目录 grep
									["<c-t>"] = "terminal", -- 在当前目录打开终端
									-- ── Git / 诊断跳转 ────────────────────────────────
									["]g"] = "explorer_git_next",
									["[g"] = "explorer_git_prev",
									["]d"] = "explorer_diagnostic_next",
									["[d"] = "explorer_diagnostic_prev",
									["]w"] = "explorer_warn_next",
									["[w"] = "explorer_warn_prev",
									["]e"] = "explorer_error_next",
									["[e"] = "explorer_error_prev",
									["?"] = "toggle_help_list", -- 显示快捷键帮助
								},
							},
						},
					},
				},
				-- filter = {
				-- 	cwd = true, -- Filter pickers by current working directory
				-- },
			},
			quickfile = { enabled = true },
			statuscolumn = { enabled = true },
			-- 与 LSP 中关闭 documentHighlight 的策略一致，避免额外光标请求。
			words = { enabled = false },
			terminal = {
				win = { position = "float", border = "rounded" },
			},
			-- styles = {
			-- 	notification = {
			-- 		wo = { wrap = true }, -- Wrap notifications
			--        -- relative = true, -- Relative time
			-- 	},
			-- },
			dashboard = {
				preset = {
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = " ", key = "e", desc = "Open", action = function() vim.api.nvim_feedkeys(":edit ", "n", false) end },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            -- { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "f", desc = "Find File", action = function() Snacks.picker.smart() end },
            { icon = " ", key = "g", desc = "Find Text", action = function() Snacks.picker.grep() end },
            { icon = " ", key = "o", desc = "Recent Files", action = function() Snacks.picker.recent() end },
            { icon = " ", key = "p", desc = "Recent Project", action = function() Snacks.picker.projects() end },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
					header = [[
███╗   ██╗███████╗ ██████╗  █████╗ ██╗██████╗  █████╗ 
████╗  ██║██╔════╝██╔═══██╗██╔══██╗██║██╔══██╗██╔══██╗
██╔██╗ ██║█████╗  ██║   ██║███████║██║██████╔╝███████║
██║╚██╗██║██╔══╝  ██║   ██║██╔══██║██║██╔══██╗██╔══██║
██║ ╚████║███████╗╚██████╔╝██║  ██║██║██║  ██║██║  ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝]],
				},
			},
		},
		config = function(_, opts)
			require("snacks").setup(opts)

			require("utils.image").setup()
		end,
		keys = {
			-- Top Pickers & Explorer
			{
				"<leader>e",
				function()
					Snacks.explorer()
				end,
				desc = "文件浏览器",
			},
			{
				"<C-e>",
				function()
					Snacks.explorer()
					vim.cmd("stopinsert")
				end,
				desc = "文件浏览器",
				mode = { "n", "i" },
			},
			{
				"<leader><space>",
				function()
					Snacks.picker.smart({ filter = { cwd = true } })
				end,
				desc = "Smart Find Files",
			},
			{
				"<leader>ff",
				function()
					Snacks.picker.files({ filter = { cwd = true } })
				end,
				desc = "Find Files",
			},
			{
				"<leader>/",
				function()
					Snacks.picker.lines()
				end,
				desc = "Grep",
			},
			{
				"<leader>sg",
				function()
					Snacks.picker.grep({ filter = { cwd = true } })
				end,
				desc = "Grep",
			},
			{
				"<leader>,",
				function()
					Snacks.picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>:",
				function()
					Snacks.picker.command_history()
				end,
				desc = "Command History",
			},
			-- {
			-- 	"<leader>n",
			-- 	function()
			-- 		Snacks.picker.notifications()
			-- 	end,
			-- 	desc = "Notification History",
			-- },
			-- find
			{
				"<leader>fb",
				function()
					Snacks.picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>fp",
				function()
					Snacks.picker.projects()
				end,
				desc = "Projects",
			},
			{
				"<leader>fo",
				function()
					Snacks.picker.recent({ filter = { cwd = true } })
				end,
				desc = "Recent",
			},
			{
				"<leader>fO",
				function()
					Snacks.picker.recent()
				end,
				desc = "Recent",
			},
			-- git
			{
				"<leader>gb",
				function()
					Snacks.picker.git_branches()
				end,
				desc = "Git Branches",
			},
			{
				"<leader>gl",
				function()
					Snacks.picker.git_log()
				end,
				desc = "Git Log",
			},
			{
				"<leader>gL",
				function()
					Snacks.picker.git_log_line()
				end,
				desc = "Git Log Line",
			},
			{
				"<leader>gs",
				function()
					Snacks.picker.git_status()
				end,
				desc = "Git Status",
			},
			{
				"<leader>gS",
				function()
					Snacks.picker.git_stash()
				end,
				desc = "Git Stash",
			},
			{
				"<leader>gd",
				function()
					Snacks.picker.git_diff()
				end,
				desc = "Git Diff (Hunks)",
			},
			{
				"<leader>gf",
				function()
					Snacks.picker.git_log_file()
				end,
				desc = "Git Log File",
			},
			-- search
			{
				'<leader>"',
				function()
					Snacks.picker.registers()
				end,
				desc = "Registers",
			},
			{
				"<leader>s/",
				function()
					Snacks.picker.search_history()
				end,
				desc = "Search History",
			},
			{
				"<leader>sd",
				function()
					Snacks.picker.diagnostics()
				end,
				desc = "Diagnostics",
			},
			{
				"<leader>sj",
				function()
					Snacks.picker.jumps()
				end,
				desc = "Jumps",
			},
			{
				"<leader>sk",
				function()
					Snacks.picker.keymaps()
				end,
				desc = "Keymaps",
			},
			{
				"<leader>sl",
				function()
					Snacks.picker.loclist()
				end,
				desc = "Location List",
			},
			{
				"<leader>m",
				function()
					Snacks.picker.marks()
				end,
				desc = "Marks",
			},
			{
				"<leader>sR",
				function()
					Snacks.picker.resume()
				end,
				desc = "Resume",
			},
			{
				"<leader>su",
				function()
					Snacks.picker.undo()
				end,
				desc = "Undo History",
			},
			{
				"<leader>uC",
				function()
					Snacks.picker.colorschemes()
				end,
				desc = "Colorschemes",
			},
			{
				"<leader>ss",
				function()
					Snacks.picker.lsp_symbols()
				end,
				desc = "LSP Symbols",
			},
			{
				"<leader>sS",
				function()
					Snacks.picker.lsp_workspace_symbols()
				end,
				desc = "LSP Workspace Symbols",
			},
			-- image（备用快捷键，K 在图片文件中会自动触发）
			{
				"<leader>ip",
				function()
					Snacks.image.hover()
				end,
				desc = "预览光标处图片",
			},
		},

		init = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				callback = function()
					-- Setup some globals for debugging (lazy-loaded)
					_G.dd = function(...)
						Snacks.debug.inspect(...)
					end
					_G.bt = function()
						Snacks.debug.backtrace()
					end
					vim.print = _G.dd -- Override print to use snacks for `:=` command
				end,
			})
		end,
	},
}

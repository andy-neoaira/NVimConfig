-- ============================================================
-- 文件名：blink-cmp.lua
-- 模块职责：blink.cmp 补全引擎主配置。
--           blink.cmp 是 nvim-cmp 的现代替代品，基于 Rust 实现核心逻辑，
--           性能优于 nvim-cmp，支持异步 source、模糊匹配、内置 snippet 等。
-- 架构定位：插件 spec 文件，由 lazy.nvim 加载。opts function 返回完整配置 table，
--           config 函数在 opts 基础上执行 setup 并附加高亮/诊断逻辑。
-- 依赖关系：
--   • saghen/blink.cmp       —— 补全引擎本体（Rust + Lua）
--   • fang2hou/blink-copilot —— Copilot 菜单式补全 source 适配器
--   • rafamadriz/friendly-snippets —— 各语言通用 snippet 片段库（仅数据）
--   • GlobalUtil（utils/）   —— 全局工具：图标、create_undo、cmp actions
-- ============================================================

return {
	-- ── 插件标识 ────────────────────────────────────────────
	"saghen/blink.cmp",
	-- 锁定大版本，避免 breaking change；patch 版本自动跟随
	version = "1.*",
	-- 不延迟加载：补全引擎需要在首次进入插入模式前就绪，
	-- 若设为 event = "InsertEnter" 会导致第一次插入时出现短暂补全缺失
	lazy = false,

	dependencies = {
		-- Copilot 菜单式补全 source（将 Copilot 建议作为普通候选项展示在菜单中）
		-- 注意：这与 copilot.vim 的幽灵文本模式互补，不重复集成
		"fang2hou/blink-copilot",
		-- friendly-snippets：仅提供 JSON/YAML 格式的片段数据库，
		-- 不包含引擎逻辑，由 blink.cmp 的 snippets source 读取并展开
		"rafamadriz/friendly-snippets",
	},

	-- ── opts：返回 blink.cmp 完整配置 table ─────────────────
	-- 使用 function 形式而非 table，是因为需要在运行时访问 GlobalUtil
	-- （GlobalUtil 在 config/init.lua 的 VeryLazy 阶段才注册到 _G）
	opts = function()
		-- 判断光标前是否存在非空白字符。
		-- 用于 <Tab> 键位：只有光标前有内容时才主动弹出补全菜单，
		-- 避免在行首或空格后按 Tab 意外触发补全（应该执行缩进）。
		-- nvim_win_get_cursor 返回 {row(1-based), col(0-based)}
		local has_words_before = function()
			local line, col = unpack(vim.api.nvim_win_get_cursor(0))
			if col == 0 then
				return false -- 光标在行首，前面没有任何字符
			end
			-- buf_get_lines 返回 0-based 行，sub(col, col) 取光标正前方字符
			-- （col 是 0-based 偏移，对应 Lua 字符串的 col 位置）
			local ch = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col)
			return ch:match("%s") == nil -- 非空白字符则返回 true
		end

		return {
			-- ── 外观配置 ──────────────────────────────────────
			appearance = {
				-- 不使用 nvim-cmp 的默认高亮组（blink 有自己的高亮体系）
				use_nvim_cmp_as_default = false,
				-- 使用 Mono 变体 Nerd Font 图标（与 lualine/neo-tree 保持一致）
				-- 可选值："mono"（单宽）| "normal"（双宽，适合东亚字体）
				nerd_font_variant = "mono",
				-- 使用 GlobalUtil.icons.kinds 中统一定义的 LSP kind 图标，
				-- 确保补全菜单与 lualine、neo-tree 等处图标风格一致
				kind_icons = GlobalUtil.icons.kinds,
			},

			-- ── 模糊匹配配置 ───────────────────────────────────
			fuzzy = {
				-- 强制使用纯 Lua 实现的模糊匹配算法。
				-- blink.cmp 默认尝试加载预编译 Rust 二进制（native），
				-- 若二进制缺失（如首次安装、架构不匹配）会打印警告。
				-- 显式指定 "lua" 可消除警告，性能差异在日常使用中可忽略
				implementation = "lua",
			},

			-- ── 补全行为配置 ───────────────────────────────────
			completion = {
				-- keyword.range：决定"关键词"的匹配范围
				-- "prefix"：只匹配光标前的部分（标准行为，如输入 "pri" 匹配 "printf"）
				-- "full"：匹配光标前后完整单词（适合替换场景，当前不需要）
				keyword = { range = "prefix" },

				-- 触发策略：控制何时自动弹出补全菜单
				trigger = {
					-- prefetch_on_insert = false：进入插入模式时不预先拉取候选。
					-- 开启后首帧会立即发起 LSP 请求，在慢速 LSP 下会造成明显卡顿；
					-- 关闭后等用户真正开始输入时再查询，体感更流畅
					prefetch_on_insert = false,
					-- 输入普通关键字字符时自动触发补全（字母/数字/下划线等）
					show_on_keyword = true,
					-- 输入 source 声明的触发字符时自动触发（如 LSP 的 "."、":" 等，
					-- 以及自定义 source 的 trigger_characters，如 miniobsidian 的 "["）
					show_on_trigger_character = true,
					-- 在 snippet 展开后的跳转点（tabstop）内也允许显示补全菜单，
					-- 方便在 snippet 填写参数时仍能获得 LSP 候选
					show_in_snippet = true,
				},

				-- 候选列表配置
				list = {
					-- 最多展示 80 个候选项，超出部分截断。
					-- LSP 有时返回数百个候选（如 Java），限制数量可减少渲染压力
					max_items = 80,
					selection = {
						-- preselect = true：菜单弹出时自动高亮第一个候选（方便直接 <CR> 确认）
						preselect = true,
						-- auto_insert：高亮候选时立即将其文本插入 buffer（虚拟预览）。
						-- checkbox 补全上下文（- [）禁用，避免导航时预插入内容触发
						-- TextChangedI → 新 context.id → 选择状态重置的 re-query 循环；
						-- 其他上下文保持 true（虚拟预览体验不变）。
						auto_insert = function(_ctx)
							local line = vim.api.nvim_get_current_line()
							local col  = vim.api.nvim_win_get_cursor(0)[2]
							local before = line:sub(1, col)
							if before:match("^%s*[-*+][%s]*%[$") then return false end
							return true
						end,
					},
				},

				-- 文档浮窗配置
				documentation = {
					-- auto_show = false：不自动弹出文档浮窗（避免遮挡视野）。
					-- 用户可按 <C-space> 或等待 auto_show_delay_ms 后手动触发
					auto_show = false,
					-- 即使 auto_show = false，此延迟也影响手动触发后的等待时间
					auto_show_delay_ms = 500,
					window = {
						border = "rounded",
						-- 映射文档浮窗高亮组到标准 NormalFloat/FloatBorder，
						-- 保持与其他浮窗（LSP hover、diagnostic float）视觉一致
						winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
					},
				},

				-- 补全菜单（弹出窗口）配置
				menu = {
					enabled = true,
					border = "rounded",
					-- 自定义菜单高亮映射：
					-- Normal → Pmenu（菜单背景）
					-- FloatBorder → PmenuBorder（边框，需主题支持）
					-- CursorLine → PmenuSel（选中项高亮）
					-- Search → None（禁用搜索高亮干扰菜单）
					winhighlight = "Normal:Pmenu,FloatBorder:PmenuBorder,CursorLine:PmenuSel,Search:None",
					auto_show = true,
					-- 触发后延迟 80ms 再渲染菜单。
					-- 快速连续输入时（如粘贴或连击）避免每个字符都重绘菜单，
					-- 减少闪烁；80ms 在感知上接近即时
					auto_show_delay_ms = 80,
					-- 自定义菜单列布局：label + 描述 | 图标 + 类型 | 来源名称
					-- source_name 显示候选来自哪个 source（lsp / buffer / MiniObsidian 等）
					draw = {
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
							{ "source_name" },
						},
					},
				},

				-- 幽灵文本（ghost text）：在光标后以灰色预览候选内容
				-- 关闭原因：与 Copilot 的幽灵文本共存时视觉混乱；
				-- 且 auto_insert = true 已提供类似的"预填"体验
				ghost_text = { enabled = false },

				-- 接受（confirm）行为
				accept = {
					-- dot_repeat = true：允许用 "." 重复上次的补全+后续编辑动作
					dot_repeat = true,
					-- 接受补全时自动创建 undo point，确保 <u> 能撤销整个补全操作
					-- （与 keymap 中 GlobalUtil.create_undo() 配合，提供完整 undo 支持）
					create_undo_point = true,
					-- 自动补全括号：接受函数类补全时自动追加 "()"
					-- blink 会根据 LSP kind（Function/Method）判断是否需要括号
					auto_brackets = { enabled = true },
				},
			},

			-- ── 键位映射 ───────────────────────────────────────
			-- blink.cmp 的 keymap 值是一个函数/动作名数组，按顺序尝试执行，
			-- 某项返回 true 则停止，返回 false 则继续下一项，
			-- "fallback" 表示将按键透传给 Neovim（执行默认行为）
			keymap = {
				-- 在文档浮窗内上下翻页（不影响菜单选择）
				-- "fallback" 确保没有文档时 <C-b>/<C-f> 仍执行页面滚动
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },

				-- <ESC>：先关闭补全菜单，再退出插入模式。
				-- 直接 fallback 会导致 blink 内部状态未清理时 Neovim 报 E785 错误，
				-- 因此手动实现两步逻辑
				["<ESC>"] = {
					function(cmp)
						-- 封装"退出插入模式"动作，加入模式检查避免在 normal 模式下重复发送 <Esc>
						local feed_esc = function()
							if vim.api.nvim_get_mode().mode ~= "n" then
								vim.api.nvim_feedkeys(
									vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
									"n",
									false
								)
							end
						end
						if cmp.is_visible() then
							cmp.cancel() -- 关闭菜单并清理 blink 内部状态
							-- vim.schedule 将 feed_esc 推迟到当前事件循环结束后执行，
							-- 确保 blink 完成清理再发送 <Esc>，避免 E785
							vim.schedule(feed_esc)
							return true -- 消费此按键，不再向下传递
						end
						feed_esc() -- 菜单未显示时直接退出插入模式
						return true
					end,
				},

				-- <CR>：接受补全 → snippet 跳转 → 普通换行（fallback）
				-- 优先级顺序：补全确认 > snippet 跳到下一个 tabstop > 换行
				["<CR>"] = {
					function(cmp)
						-- 接受补全前先创建 undo point，使 <u> 能完整撤销补全+后续输入
						GlobalUtil.create_undo()
						if cmp.is_visible() then
							return cmp.accept() -- 确认当前高亮的候选项
						elseif GlobalUtil.cmp.actions.snippet_forward() then
							-- snippet 跳转到下一个 tabstop（${1}→${2}→...→${0}）
							return true
						end
						return false -- 交给 "fallback" 处理（插入换行）
					end,
					"fallback",
				},

				-- <Tab>：AI 接受 → 补全确认 → snippet 跳转 → 触发补全 → 缩进（fallback）
				-- 这是最复杂的键位，覆盖了 Copilot + blink + snippet 三者的协作
				["<Tab>"] = {
					function(cmp)
						GlobalUtil.create_undo()
						-- 1. 优先接受 Copilot 幽灵文本建议（如果有）
						if GlobalUtil.cmp.actions.ai_accept() then
							return true
						-- 2. 补全菜单可见时确认当前候选
						elseif cmp.is_visible() then
							return cmp.accept()
						-- 3. 在 snippet 展开状态中跳到下一个 tabstop
						elseif GlobalUtil.cmp.actions.snippet_forward() then
							return true
						-- 4. 光标前有内容但菜单未显示：主动弹出候选列表
						elseif has_words_before() then
							cmp.show()
							return true
						end
						-- 5. 以上均不满足（如行首）：执行普通 Tab 缩进
						return false
					end,
					"fallback",
				},

				-- <F13>：手动触发补全菜单（用于映射 ctrl+enter 等快捷键的终端转义码）
				-- 某些终端无法发送 <C-Space>，通过终端配置将其映射为 F13 后在此处理
				["<F13>"] = { "show", "fallback" },
			},

			-- ── Snippet（代码片段）配置 ────────────────────────
			-- blink.cmp 内置 snippet source，读取 friendly-snippets 的数据，
			-- 使用 Neovim 原生 vim.snippet API（>= 0.10）展开和跳转
			snippets = {
				-- "default" 预设：使用 vim.snippet 作为展开引擎
				-- 备选："luasnip" / "mini_snippets"（需对应插件）
				preset = "default",
				-- 展开 snippet 内容：委托给 GlobalUtil.cmp.expand，
				-- 内部调用 vim.snippet.expand(snippet)
				expand = function(snippet)
					GlobalUtil.cmp.expand(snippet)
				end,
				-- 查询当前是否处于 snippet 激活状态（有未完成的 tabstop）
				-- blink 用此判断 <Tab> 是否应执行 snippet 跳转
				active = function(filter)
					return vim.snippet.active(filter)
				end,
				-- 跳转到 snippet 的上一个（dir=-1）或下一个（dir=1）tabstop
				jump = function(dir)
					vim.snippet.jump(dir)
				end,
			},

			-- ── 补全源配置 ─────────────────────────────────────
			sources = {
				-- 默认激活的 source 列表（按优先级排列，score_offset 会进一步调整）：
				-- lsp → path → snippets → buffer → copilot
				-- 其他插件（如 miniobsidian）通过各自的 lazy spec 追加到此列表
				default = { "lsp", "path", "snippets", "buffer", "copilot" },

				providers = {
					-- LSP source：调用当前 buffer 关联的 LSP 服务器获取补全
					lsp = {
						name = "lsp",
						module = "blink.cmp.sources.lsp",
						-- 限制 LSP 候选数量：部分语言服务器（Java/PHP）会返回大量候选，
						-- 限制 80 个可有效缩短渲染时间，配合 list.max_items 双重保障
						max_items = 80,
					},

					-- Buffer source：扫描当前（及其他）buffer 的文本作为候选
					buffer = {
						name = "buffer",
						module = "blink.cmp.sources.buffer",
						-- 限制 buffer 候选数量（buffer 扫描较耗 CPU）
						max_items = 50,
						-- 至少输入 2 个字符才触发 buffer 补全，
						-- 避免单字符就扫描整个 buffer（性能 + 减少噪音候选）
						min_keyword_length = 2,
					},

					-- Copilot source（via blink-copilot 适配器）：
					-- 将 Copilot 的建议作为普通候选项插入菜单
					copilot = {
						name = "copilot",
						module = "blink-copilot",
					-- only enable copilot source when not in markdown files
					enabled = function() return vim.bo.filetype ~= "markdown" end,
						-- score_offset = 100：大幅提高排序分数，确保 Copilot 建议始终靠前显示；
						-- blink 的最终排序 = 基础分 + score_offset，100 足以超过 LSP/buffer
						score_offset = 100,
						-- async = true：Copilot 网络请求异步进行，不阻塞补全菜单渲染
						async = true,
					},

					-- lazydev source：为 Lua 配置文件提供 Neovim API 类型感知补全
					-- （vim.api.*、vim.fn.*、插件类型等）
					-- 条件加载：仅在 lazydev.nvim 已安装时注册，避免报错
					lazydev = GlobalUtil.has("lazydev.nvim") and {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						-- 高优先级，确保 Lua 文件中 Neovim API 候选优先于通用 LSP 候选
						score_offset = 100,
					} or nil,
				},
			},

			-- ── 命令行补全配置 ─────────────────────────────────
			-- blink.cmp 可以在 ":" 命令行模式下提供补全（命令名、参数、路径等）
			cmdline = {
				enabled = true,
				keymap = {
					-- 使用内置 "cmdline" 预设（<Tab>/<S-Tab> 循环候选，<CR> 确认）
					preset = "cmdline",
					-- 禁用 <Right>/<Left> 在菜单中的选择行为：
					-- 命令行中方向键应用于光标移动，而非候选选择
					["<Right>"] = false,
					["<Left>"] = false,
				},
				completion = {
					list = {
						selection = {
							-- 命令行补全不自动预选第一项：
							-- 命令行场景中用户通常想看完所有候选再决定，
							-- 预选会自动填充候选文本干扰输入
							preselect = false,
						},
					},
				},
			},
		}
	end,

	-- ── config：setup 后的额外初始化逻辑 ──────────────────────
	-- 此函数在 opts 合并（含其他 spec 的 opts.sources.providers 追加）后执行
	config = function(_, opts)
		local blink = require("blink.cmp")
		blink.setup(opts)

		-- 统一幽灵文本高亮组：链接到 Comment 高亮（灰色），
		-- default = true 表示如果主题已定义 BlinkCmpGhostText 则不覆盖
		vim.api.nvim_set_hl(0, "BlinkCmpGhostText", { link = "Comment", default = true })

		-- ── 性能诊断模式（按需启用）──────────────────────────
		-- 启用方式：在 init.lua 或命令行中设置 vim.g.blink_diag = true，
		-- 然后重启 Neovim；日志写入 /tmp/blink_diag.log
		-- 用途：定位"补全菜单出现慢"问题，区分是 LSP 慢还是 blink 渲染慢
		if vim.g.blink_diag == true then
			local logfile = "/tmp/blink_diag.log"
			-- 封装写日志函数，pcall 保护避免写文件失败导致整体报错
			local function log(msg)
				pcall(vim.fn.writefile, { os.date("%H:%M:%S ") .. msg }, logfile, "a")
			end

			-- Monkey-patch vim.lsp.buf_request：记录每次 LSP 请求的耗时
			-- 原理：包装 handler 回调，在回调触发时计算从发起请求到收到响应的毫秒数
			-- 注意：此 patch 是全局的，会影响所有 LSP 请求（不只是补全）
			local orig_req = vim.lsp.buf_request
			vim.lsp.buf_request = function(buf, method, params, handler)
				local t0 = vim.uv.hrtime() -- 高精度时间戳（纳秒）
				local wrapped = function(err, result, ctx, cfg)
					local ms = (vim.uv.hrtime() - t0) / 1e6 -- 转换为毫秒
					log(string.format("LSP %s %.1fms (client=%s)", method, ms, ctx and ctx.client_id or "-"))
					-- 优先使用调用方传入的 handler，否则使用全局默认 handler
					if handler then
						return handler(err, result, ctx, cfg)
					end
					local h = vim.lsp.handlers[method]
					return h and h(err, result, ctx, cfg)
				end
				return orig_req(buf, method, params, wrapped)
			end

			-- Monkey-patch blink.show：记录从调用 show() 到菜单真正可见的耗时
			-- 原理：轮询 blink.is_visible()，记录首次可见时的耗时
			-- tries > 50（即 50 × 5ms = 250ms）作为超时保护，避免无限轮询
			local orig_show = blink.show
			blink.show = function(...)
				local t0 = vim.uv.hrtime()
				local ret = orig_show(...)
				local tries = 0
				local function poll()
					tries = tries + 1
					if blink.is_visible() or tries > 50 then
						local ms = (vim.uv.hrtime() - t0) / 1e6
						log(string.format("MENU visible %.1fms (tries=%d)", ms, tries))
					else
						vim.defer_fn(poll, 5) -- 每 5ms 检查一次
					end
				end
				vim.defer_fn(poll, 0) -- 下一个事件循环开始轮询
				return ret
			end

			-- 记录输入事件：追踪触发补全的具体字符和文件类型，
			-- 用于排查"某类文件不触发补全"的问题
			vim.api.nvim_create_autocmd({ "TextChangedI", "InsertCharPre" }, {
				callback = function(ev)
					log("EV " .. ev.event .. " col=" .. vim.fn.col(".") .. " ft=" .. vim.bo.filetype)
				end,
			})
			log("--- blink diag start ---")
		end
	end,
}

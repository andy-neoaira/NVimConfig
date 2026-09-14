local M = {}

---@return {fg?:string}?
function M.fg(name)
	local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
	local fg = hl and hl.fg
	return fg and { fg = string.format("#%06x", fg) } or nil
end

---@param component any
---@param text string
---@param hl_group? string
---@return string
function M.format(component, text, hl_group)
	text = text:gsub("%%", "%%%%")
	if not hl_group or hl_group == "" then
		return text
	end
	---@type table<string, string>
	component.hl_cache = component.hl_cache or {}
	local lualine_hl_group = component.hl_cache[hl_group]
	if not lualine_hl_group then
		local utils = require("lualine.utils.utils")
		---@type string[]
		local gui = vim.tbl_filter(function(x)
			return x
		end, {
			utils.extract_highlight_colors(hl_group, "bold") and "bold",
			utils.extract_highlight_colors(hl_group, "italic") and "italic",
		})

		lualine_hl_group = component:create_hl({
			fg = utils.extract_highlight_colors(hl_group, "fg"),
			gui = #gui > 0 and table.concat(gui, ",") or nil,
		}, "LV_" .. hl_group) --[[@as string]]
		component.hl_cache[hl_group] = lualine_hl_group
	end
	return component:format_hl(lualine_hl_group) .. text .. component:get_default_hl()
end

return {
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		init = function()
			vim.g.lualine_laststatus = vim.o.laststatus
			if vim.fn.argc(-1) > 0 then
				-- set an empty statusline till lualine loads
				vim.o.statusline = " "
			else
				-- hide the statusline on the starter page
				vim.o.laststatus = 0
			end
		end,
		opts = function()
			-- PERF: we don't need this lualine require madness 🤷
			local lualine_require = require("lualine_require")
			lualine_require.require = require

			local icons = GlobalUtil.icons

			vim.o.laststatus = vim.g.lualine_laststatus

			local opts = {
				options = {
					theme = "auto",
					globalstatus = vim.o.laststatus == 3,
					disabled_filetypes = { statusline = { "snacks_dashboard", "alpha", "ministarter" } },
					section_separators = "",
					component_separators = "",
				},
				sections = {
					--模式
					lualine_a = { "mode" },
					--分支
					lualine_b = {
						{ "branch" },
					},
					lualine_c = {
						--文件类型
						{
							"filetype",
							icon_only = true,
							separator = "",
							padding = { left = 1, right = 0 },
						},
						{
							function()
								local venv_path = os.getenv("VIRTUAL_ENV")
								if venv_path == nil then
									return ""
								end
								return "(" .. vim.fn.fnamemodify(venv_path, ":t") .. ")"
							end,
							padding = { left = 0, right = 1 },
							color = { fg = "#ff9e64" },
						},
						-- 文件路径
						{
							function(self)
								local modified_hl = "MatchParen"
								local length = 3
								local path = vim.fn.expand("%:p") --[[@as string]]
								if path == "" then
									return ""
								end

								local cwd = GlobalUtil.root.cwd()
								path = path:sub(#cwd + 2)

								local sep = package.config:sub(1, 1)
								local parts = vim.split(path, "[\\/]")

								if #parts > length then
									parts = { parts[1], "…", unpack(parts, #parts - length + 2, #parts) }
								end

								if modified_hl and vim.bo.modified then
									parts[#parts] = parts[#parts]
									parts[#parts] = M.format(self, parts[#parts], modified_hl)
								else
									parts[#parts] = M.format(self, parts[#parts], "Bold")
								end

								local dir = ""
								if #parts > 1 then
									dir = table.concat({ unpack(parts, 1, #parts - 1) }, sep)
									dir = M.format(self, dir .. sep, "")
								end

								local readonly = ""
								if vim.bo.readonly then
									readonly = M.format(self, " 󰌾 ", modified_hl)
								end
								return dir .. parts[#parts] .. readonly
							end,
						},
					},
					lualine_x = {
						Snacks.profiler.status(),
						{
							function()
								return "  " .. require("dap").status()
							end,
							cond = function()
								return package.loaded["dap"] and require("dap").status() ~= ""
							end,
							color = function()
								return { fg = Snacks.util.color("Debug") }
							end,
						},
						{
							function()
								local icon = GlobalUtil.icons.kinds.Copilot
								local status = require("copilot.status").data
								return icon .. (status.message or "")
							end,
							cond = function()
								if not package.loaded["copilot"] then
									return false
								end
								local ok, clients = pcall(GlobalUtil.lsp.get_clients, { name = "copilot", bufnr = 0 })
								return ok and #clients > 0
							end,
							color = function()
								if not package.loaded["copilot"] then
									return
								end
								local status = require("copilot.status").data
								return M.fg(
									(status == nil and "DiagnosticError")
										or (status.status == "InProgress" and "DiagnosticWarn")
										or (status.status == "Warning" and "DiagnosticError")
										or "Special"
								)
							end,
						},
						{
							"diff",
							symbols = {
								added = icons.git.added,
								modified = icons.git.modified,
								removed = icons.git.removed,
							},
							source = function()
								local gitsigns = vim.b.gitsigns_status_dict
								if gitsigns then
									return {
										added = gitsigns.added,
										modified = gitsigns.changed,
										removed = gitsigns.removed,
									}
								end
							end,
						},
						{
							"diagnostics",
							symbols = {
								error = icons.diagnostics.Error,
								warn = icons.diagnostics.Warn,
								info = icons.diagnostics.Info,
								hint = icons.diagnostics.Hint,
							},
							--只显示警告和错误
							sections = { "error", "warn" },
						},
					},
					lualine_y = {
						{ "fileformat" },
						{ "encoding", padding = { left = 0, right = 1 } },
					},
					lualine_z = {
						{ "progress", separator = " ", padding = { left = 1, right = 0 } },
						{ "location", padding = { left = 0, right = 1 } },
					},
				},
				extensions = {
					"lazy",
					-- snacks explorer 侧边栏：隐藏状态栏多余信息
					{
						filetypes = { "snacks_picker_list" },
						sections = {},
						inactive_sections = {},
					},
				},
			}

			-- do not add trouble symbols if aerial is enabled
			-- And allow it to be overriden for some buffer types (see autocmds)
			if vim.g.trouble_lualine and GlobalUtil.has("trouble.nvim") then
				local trouble = require("trouble")
				local symbols = trouble.statusline({
					mode = "symbols",
					groups = {},
					title = false,
					filter = { range = true },
					format = "{kind_icon}{symbol.name:Normal}",
					hl_group = "lualine_c_normal",
				})
				table.insert(opts.sections.lualine_c, {
					symbols and symbols.get,
					cond = function()
						return vim.b.trouble_lualine ~= false and symbols.has()
					end,
				})
			end

			return opts
		end,
	},
}

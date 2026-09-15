return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufNewFile", "BufWritePre" },
	opts = {
		-- Event to trigger linters
		events = { "BufWritePost", "BufReadPost", "InsertLeave" },
		linters_by_ft = {
			fish = { "fish" },
			-- Use the "*" filetype to run linters on all filetypes.
			-- ['*'] = { 'global linter' },
			-- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
			-- ['_'] = { 'fallback linter' },
			-- ["*"] = { "typos" },
		},
		-- LazyVim extension to easily override linter options
		-- or add custom linters.
		---@type table<string,table>
		linters = {
			-- -- Example of using selene only when a selene.toml file is present
			-- selene = {
			--   -- `condition` is another LazyVim extension that allows you to
			--   -- dynamically enable/disable linters based on the context.
			--   condition = function(ctx)
			--     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
			--   end,
			-- },
		},
	},
	config = function(_, opts)
		local M = {}

		local lint = require("lint")
		for name, linter in pairs(opts.linters) do
			if type(linter) == "table" and type(lint.linters[name]) == "table" then
				lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
				if type(linter.prepend_args) == "table" then
					lint.linters[name].args = lint.linters[name].args or {}
					lint.linters[name].args =
						vim.list_extend(vim.deepcopy(linter.prepend_args), lint.linters[name].args)
				end
			else
				lint.linters[name] = linter
			end
		end
		lint.linters_by_ft = opts.linters_by_ft

		function M.debounce(ms, fn)
			-- 每个缓冲区独立防抖，切换窗口不会把诊断发给新窗口中的文件。
			local pending = {}
			return function(event)
				local buf, token = event.buf, {}
				pending[buf] = token
				vim.defer_fn(function()
					if pending[buf] ~= token then
						return
					end
					pending[buf] = nil
					if
						vim.api.nvim_buf_is_valid(buf)
						and vim.api.nvim_buf_is_loaded(buf)
						and vim.bo[buf].buftype == ""
					then
						vim.api.nvim_buf_call(buf, fn)
					end
				end, ms)
			end
		end

		function M.lint()
			-- Use nvim-lint's logic first:
			-- * checks if linters exist for the full filetype first
			-- * otherwise will split filetype by "." and add all those linters
			-- * this differs from conform.nvim which only uses the first filetype that has a formatter
			local names = lint._resolve_linter_by_ft(vim.bo.filetype)

			-- Create a copy of the names table to avoid modifying the original.
			names = vim.list_extend({}, names)

			-- Add fallback linters.
			if #names == 0 then
				vim.list_extend(names, lint.linters_by_ft["_"] or {})
			end

			-- Add global linters.
			vim.list_extend(names, lint.linters_by_ft["*"] or {})

			-- Filter out linters that don't exist or don't match the condition.
			local ctx = { filename = vim.api.nvim_buf_get_name(0) }
			ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
			names = vim.tbl_filter(function(name)
				local linter = lint.linters[name]
				if not linter then
					GlobalUtil.warn("Linter not found: " .. name, { title = "nvim-lint" })
				end
				return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
			end, names)

			-- Run linters.
			if #names > 0 then
				lint.try_lint(names)
			end
		end

		vim.api.nvim_create_autocmd(opts.events, {
			group = vim.api.nvim_create_augroup("custom_nvim_lint", { clear = true }),
			callback = M.debounce(100, M.lint),
		})
	end,
}

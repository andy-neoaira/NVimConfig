---@alias LazyKeysLspSpec LazyKeysSpec|{has?:string|string[], cond?:fun():boolean}
---@alias LazyKeysLsp LazyKeys|{has?:string|string[], cond?:fun():boolean}
local M = {}

---@return LazyKeysLspSpec[]
function M.get_keys()
	return {
		{
			"<leader>cl",
			"<cmd>LspInfo<cr>",
			desc = "Lsp Info",
		},
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "Goto Definition",
			has = "definition",
		},
		{
			"gr",
			function()
				Snacks.picker.lsp_references()
			end,
			desc = "References",
			nowait = true,
		},
		{
			"gi",
			function()
				Snacks.picker.lsp_implementations()
			end,
			desc = "Goto Implementation",
		},
		{
			"gy",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "Goto T[y]pe Definition",
		},
		{
			"gD",
			vim.lsp.buf.declaration,
			desc = "Goto Declaration",
		},
		{
			"K",
			function()
				local file = vim.fn.expand("%:p")
				local ft = vim.bo.filetype
				local doc_fts = {
					markdown = true,
					html = true,
					norg = true,
					tsx = true,
					javascript = true,
					css = true,
					vue = true,
					svelte = true,
				}
				local has_lsp = #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/hover" }) > 0
				if Snacks.image.supports(file) then
					-- 当前文件本身就是图片（.png/.jpg 等）
					Snacks.image.hover()
				elseif doc_fts[ft] then
					-- snacks 通过 treesitter 同时处理 ![]() 和 ![[]] 两种格式
					-- kitty inline 模式下不注册 CursorMoved 关闭，手动补一次性 autocmd
					Snacks.image.hover()
					local buf = vim.api.nvim_get_current_buf()
					vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave", "InsertEnter" }, {
						buffer = buf,
						once = true,
						callback = function()
							Snacks.image.doc.hover_close()
						end,
					})
					if has_lsp then
						vim.lsp.buf.hover()
					end
				else
					vim.lsp.buf.hover()
				end
			end,
			desc = "Hover / 预览图片",
		},
		{
			"gK",
			function()
				return vim.lsp.buf.signature_help()
			end,
			desc = "Signature Help",
		},
		{
			"<F14>",
			vim.lsp.buf.code_action,
			desc = "Code Action",
			mode = { "i", "n", "v" },
			has = "codeAction",
		},
		{
			"<leader>ca",
			vim.lsp.buf.code_action,
			desc = "Code Action",
			mode = { "n", "v" },
			has = "codeAction",
		},
		{
			"<leader>cc",
			vim.lsp.codelens.run,
			desc = "Run Codelens",
			mode = { "n", "v" },
			has = "codeLens",
		},
		{
			"<leader>cC",
			vim.lsp.codelens.refresh,
			desc = "Refresh & Display Codelens",
			mode = { "n" },
			has = "codeLens",
		},
		{
			"<leader>cR",
			function()
				Snacks.rename.rename_file()
			end,
			desc = "Rename File",
			mode = { "n" },
			has = { "workspace/didRenameFiles", "workspace/willRenameFiles" },
		},
		{
			"<leader>cr",
			vim.lsp.buf.rename,
			desc = "Rename",
			has = "rename",
		},
		{
			"<leader>cA",
			GlobalUtil.lsp.action.source,
			desc = "Source Action",
			has = "codeAction",
		},
		{
			"<leader>ss",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "document_symbols",
		},
	}
end

---@param method string|string[]
function M.has(buffer, method)
	if type(method) == "table" then
		for _, m in ipairs(method) do
			if M.has(buffer, m) then
				return true
			end
		end
		return false
	end
	method = method:find("/") and method or "textDocument/" .. method
	local clients = GlobalUtil.lsp.get_clients({ bufnr = buffer })
	for _, client in ipairs(clients) do
		if client:supports_method(method, buffer) then
			return true
		end
	end
	return false
end

---@return LazyKeysLsp[]
function M.resolve(buffer)
	local Keys = require("lazy.core.handler.keys")
	if not Keys.resolve then
		return {}
	end
	local spec = M.get_keys()
	local opts = GlobalUtil.opts("nvim-lspconfig")
	local clients = GlobalUtil.lsp.get_clients({ bufnr = buffer })
	for _, client in ipairs(clients) do
		local server = opts.servers[client.name]
		local maps = type(server) == "table" and server.keys or {}
		vim.list_extend(spec, maps)
	end
	return Keys.resolve(spec)
end

function M.on_attach(_, buffer)
	local Keys = require("lazy.core.handler.keys")
	local keymaps = M.resolve(buffer)

	for _, keys in pairs(keymaps) do
		local has = not keys.has or M.has(buffer, keys.has)

		if has and (not keys.cond or keys.cond()) then
			local opts = Keys.opts(keys)
			opts.cond = nil
			opts.has = nil
			opts.silent = opts.silent ~= false
			opts.buffer = buffer
			vim.keymap.set(keys.mode or "n", keys.lhs, keys.rhs, opts)
		end
	end
end

return M

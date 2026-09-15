return {
	-- lspconfig
	{
		"neovim/nvim-lspconfig",
		event = { "FileType", "BufReadPost", "BufNewFile", "BufWritePre" },
		dependencies = {
			"mason.nvim",
			{ "mason-org/mason-lspconfig.nvim", config = function() end },
		},
		opts = function()
			return require("utils.lsp_options").get()
		end,

		---@param opts PluginLspOpts
		config = function(_, opts)
			-- setup autoformat
			GlobalUtil.format.register(GlobalUtil.lsp.formatter())

			-- setup keymaps
			GlobalUtil.lsp.on_attach(function(client, buffer)
				require("utils.lsp_keymaps").on_attach(client, buffer)
			end)

			GlobalUtil.lsp.setup()
			GlobalUtil.lsp.on_dynamic_capability(require("utils.lsp_keymaps").on_attach)

			-- inlay hints
			if opts.inlay_hints.enabled then
				GlobalUtil.lsp.on_supports_method("textDocument/inlayHint", function(client, buffer)
					if
						vim.api.nvim_buf_is_valid(buffer)
						and vim.bo[buffer].buftype == ""
						and not vim.tbl_contains(opts.inlay_hints.exclude, vim.bo[buffer].filetype)
					then
						vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
					end
				end)
			end

			-- code lens
			if opts.codelens.enabled and vim.lsp.codelens then
				GlobalUtil.lsp.on_supports_method("textDocument/codeLens", function(client, buffer)
					vim.lsp.codelens.refresh()
					vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
						buffer = buffer,
						callback = vim.lsp.codelens.refresh,
					})
				end)
			end

			-- diagnostics
			if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
				opts.diagnostics.virtual_text.prefix = function(diagnostic)
					local icons = GlobalUtil.icons.diagnostics
					for d, icon in pairs(icons) do
						if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
							return icon
						end
					end
					return "●"
				end
			end
			vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

			-- 合并 blink.cmp 的补全能力并注入到所有 LSP（确保 LSP 补全可用）
			local caps = (pcall(require, "blink.cmp") and require("blink.cmp").get_lsp_capabilities())
				or vim.lsp.protocol.make_client_capabilities()
			-- 统一 position encodings，避免多客户端混用导致位置计算差异
			caps.general = caps.general or {}
			caps.general.positionEncodings = { "utf-16" }
			caps = vim.tbl_deep_extend("force", caps, opts.capabilities or {})
			vim.lsp.config("*", { capabilities = caps })

			-- get all the servers that are available through mason-lspconfig
			local have_mason = GlobalUtil.has("mason-lspconfig.nvim")
			local mason_all = have_mason
					and vim.tbl_keys(require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package)
				or {} --[[ @as string[] ]]

			-- 仅显式声明的服务器参与启用，Mason 中安装过的其他服务器保持关闭。

			local function configure(server)
				local server_opts = opts.servers[server]
				server_opts = type(server_opts) == "table" and vim.deepcopy(server_opts) or {}

				local setup = opts.setup[server] or opts.setup["*"]
				if setup and setup(server, server_opts) then
					return true -- lsp will be setup by the setup function
				end

				-- enabled/mason/keys 是配置框架字段，不发送给语言服务器。
				local mason_enabled = server_opts.mason ~= false
				server_opts.enabled, server_opts.mason, server_opts.keys = nil, nil, nil
				vim.lsp.config(server, server_opts)

				-- manually enable if mason=false or if this is a server that cannot be installed with mason-lspconfig
				if not mason_enabled or not vim.tbl_contains(mason_all, server) then
					vim.lsp.enable(server)
					return true
				end
				return false
			end

			local ensure_installed = {} ---@type string[]
			for server, server_opts in pairs(opts.servers) do
				server_opts = server_opts == true and {} or server_opts or false
				if server_opts and server_opts.enabled ~= false then
					-- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
					if configure(server) then
						-- 此服务器由自定义配置管理。
					else
						ensure_installed[#ensure_installed + 1] = server
					end
				end
			end

			if have_mason then
				require("mason-lspconfig").setup({
					-- 白名单避免激活 Mason 中历史安装的其他语言服务器。
					automatic_enable = ensure_installed,
					-- 安装统一通过 :ToolsInstall，打开文件不触发下载。
					ensure_installed = {},
				})
			end

			if vim.lsp.is_enabled and vim.lsp.is_enabled("denols") and vim.lsp.is_enabled("vtsls") then
				---@param server string
				local resolve = function(server)
					local markers, root_dir = vim.lsp.config[server].root_markers, vim.lsp.config[server].root_dir
					vim.lsp.config(server, {
						root_dir = function(bufnr, on_dir)
							local is_deno = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" }) ~= nil
							if is_deno == (server == "denols") then
								if root_dir then
									return root_dir(bufnr, on_dir)
								elseif type(markers) == "table" then
									local root = vim.fs.root(bufnr, markers)
									return root and on_dir(root)
								end
							end
						end,
					})
				end
				resolve("denols")
				resolve("vtsls")
			end
		end,
	},
}

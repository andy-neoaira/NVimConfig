---@alias LazyKeysLspSpec LazyKeysSpec|{has?:string|string[], cond?:fun():boolean}
---@alias LazyKeysLsp LazyKeys|{has?:string|string[], cond?:fun():boolean}
local M = {}

---@return LazyKeysLspSpec[]
function M.getKeys()
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
				local doc_fts = { markdown = true, html = true, norg = true, tsx = true, javascript = true, css = true, vue = true, svelte = true }
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
			mode = {"i", "n", "v" },
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
		if client:supports_method(method) then
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
	local spec = M.getKeys()
	local opts = GlobalUtil.opts("nvim-lspconfig")
	local clients = GlobalUtil.lsp.get_clients({ bufnr = buffer })
	for _, client in ipairs(clients) do
		local maps = opts.servers[client.name] and opts.servers[client.name].keys or {}
		vim.list_extend(spec, maps)
	end
	return Keys.resolve(spec)
end

function M.on_attach(_, buffer)
	local Keys = require("lazy.core.handler.keys")
	local keymaps = M.resolve(buffer)

	for _, keys in pairs(keymaps) do
		local has = not keys.has or M.has(buffer, keys.has)

		if has then
			local opts = Keys.opts(keys)
			opts.cond = nil
			opts.has = nil
			opts.silent = opts.silent ~= false
			opts.buffer = buffer
			vim.keymap.set(keys.mode or "n", keys.lhs, keys.rhs, opts)
		end
	end
end

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
			---@class PluginLspOpts
			local ret = {
				-- options for vim.diagnostic.config()
				---@type vim.diagnostic.Opts
				diagnostics = {
					underline = true,
					update_in_insert = false,
					virtual_text = {
						spacing = 4,
						source = "if_many",
						prefix = "●",
						-- this will set set the prefix to a function that returns the diagnostics icon based on the severity
						-- this only works on a recent 0.10.0 build. Will be set to "●" when not supported
						-- prefix = "icons",
					},
					severity_sort = true,
					signs = {
						text = {
							[vim.diagnostic.severity.ERROR] = GlobalUtil.icons.diagnostics.Error,
							[vim.diagnostic.severity.WARN] = GlobalUtil.icons.diagnostics.Warn,
							[vim.diagnostic.severity.HINT] = GlobalUtil.icons.diagnostics.Hint,
							[vim.diagnostic.severity.INFO] = GlobalUtil.icons.diagnostics.Info,
						},
					},
				},
				-- Enable this to enable the builtin LSP inlay hints on Neovim >= 0.10.0
				-- Be aware that you also will need to properly configure your LSP server to
				-- provide the inlay hints.
				inlay_hints = {
					enabled = true,
					exclude = { "vue", "python" }, -- 排除 python，降低插入态额外计算
				},
				-- Enable this to enable the builtin LSP code lenses on Neovim >= 0.10.0
				-- Be aware that you also will need to properly configure your LSP server to
				-- provide the code lenses.
				codelens = {
					enabled = false,
				},
				-- Disable LSP cursor word highlighting（避免高延迟的 documentHighlight 阻塞补全）
				document_highlight = {
					enabled = false,
				},
				-- add any global capabilities here
				capabilities = {
					workspace = {
						fileOperations = {
							didRename = true,
							willRename = true,
						},
					},
				},
				-- options for vim.lsp.buf.format
				-- `bufnr` and `filter` is handled by the LazyVim formatter,
				-- but can be also overridden when specified
				format = {
					formatting_options = nil,
					timeout_ms = nil,
				},
				-- LSP Server Settings
				servers = {
					-- jdtls 由 nvim-jdtls 插件独立管理，禁止 mason-lspconfig 自动启用
					jdtls = { enabled = false },
					-- markdown
					markdown_oxide = {},
					lua_ls = {
						settings = {
							Lua = {
								workspace = {
									checkThirdParty = false,
								},
								codeLens = {
									enable = true,
								},
								completion = {
									callSnippet = "Replace",
								},
								doc = {
									privateName = { "^_" },
								},
								hint = {
									enable = true,
									setType = false,
									paramType = true,
									paramName = "Disable",
									semicolon = "Disable",
									arrayIndex = "Disable",
								},
							},
						},
					},
					--c
					neocmake = {},
					--docker
					dockerls = {},
					docker_compose_language_service = {},
					--json
					jsonls = {
						-- lazy-load schemastore when needed
						on_new_config = function(new_config)
							new_config.settings.json.schemas = new_config.settings.json.schemas or {}
							vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
						end,
						settings = {
							json = {
								format = {
									enable = true,
								},
								validate = { enable = true },
							},
						},
					},
					--nushell
					nushell = {},
					--python
					-- pyright = { enabled = true },
					basedpyright = {
						enabled = true,
						settings = {
							basedpyright = {
								analysis = {
									typeCheckingMode = "basic",
								},
							},
						},
					},
					ruff = {
						enabled = true,
						cmd_env = { RUFF_TRACE = "messages" },
						init_options = {
							settings = { logLevel = "error" },
						},
					},
					--toml
					taplo = {},
					--- @deprecated -- tsserver renamed to ts_ls but not yet released, so keep this for now
					--- the proper approach is to check the nvim-lspconfig release version when it's released to determine the server name dynamically
					tsserver = {
						enabled = false,
					},
					ts_ls = {
						enabled = false,
					},
					vtsls = {
						-- explicitly add default filetypes, so that we can extend
						-- them in related extras
						filetypes = {
							"javascript",
							"javascriptreact",
							"javascript.jsx",
							"typescript",
							"typescriptreact",
							"typescript.tsx",
							"vue",
						},
						settings = {
							complete_function_calls = true,
							vtsls = {
								tsserver = {
									globalPlugins = {
										{
											name = "@vue/typescript-plugin",
											location = GlobalUtil.get_pkg_path(
												"vue-language-server",
												"/node_modules/@vue/language-server"
											),
											languages = { "vue" },
											configNamespace = "typescript",
											enableForWorkspaceTypeScriptVersions = true,
										},
									},
								},
								enableMoveToFileCodeAction = true,
								autoUseWorkspaceTsdk = true,
								experimental = {
									maxInlayHintLength = 30,
									completion = {
										enableServerSideFuzzyMatch = true,
									},
								},
							},
							typescript = {
								updateImportsOnFileMove = { enabled = "always" },
								suggest = {
									completeFunctionCalls = true,
								},
								inlayHints = {
									enumMemberValues = { enabled = true },
									functionLikeReturnTypes = { enabled = true },
									parameterNames = { enabled = "literals" },
									parameterTypes = { enabled = true },
									propertyDeclarationTypes = { enabled = true },
									variableTypes = { enabled = false },
								},
							},
						},
						-- keys = {
						-- 	{
						-- 		"gD",
						-- 		function()
						-- 			local params = vim.lsp.util.make_position_params()
						-- 			GlobalUtil.lsp.execute({
						-- 				command = "typescript.goToSourceDefinition",
						-- 				arguments = { params.textDocument.uri, params.position },
						-- 				open = true,
						-- 			})
						-- 		end,
						-- 		desc = "Goto Source Definition",
						-- 	},
						-- 	{
						-- 		"gR",
						-- 		function()
						-- 			GlobalUtil.lsp.execute({
						-- 				command = "typescript.findAllFileReferences",
						-- 				arguments = { vim.uri_from_bufnr(0) },
						-- 				open = true,
						-- 			})
						-- 		end,
						-- 		desc = "File References",
						-- 	},
						-- 	{
						-- 		"<leader>co",
						-- 		GlobalUtil.lsp.action["source.organizeImports"],
						-- 		desc = "Organize Imports",
						-- 	},
						-- 	{
						-- 		"<leader>cM",
						-- 		GlobalUtil.lsp.action["source.addMissingImports.ts"],
						-- 		desc = "Add missing imports",
						-- 	},
						-- 	{
						-- 		"<leader>cu",
						-- 		GlobalUtil.lsp.action["source.removeUnused.ts"],
						-- 		desc = "Remove unused imports",
						-- 	},
						-- 	{
						-- 		"<leader>cD",
						-- 		GlobalUtil.lsp.action["source.fixAll.ts"],
						-- 		desc = "Fix all diagnostics",
						-- 	},
						-- 	{
						-- 		"<leader>cV",
						-- 		function()
						-- 			GlobalUtil.lsp.execute({ command = "typescript.selectTypeScriptVersion" })
						-- 		end,
						-- 		desc = "Select TS workspace version",
						-- 	},
						-- },
						volar = {
							init_options = {
								vue = {
									hybridMode = true,
								},
							},
						},
					},
				},
				-- you can do any additional lsp server setup here
				-- return true if you don't want this server to be setup with lspconfig
				setup = {
					-- example to setup with typescript.nvim
					-- tsserver = function(_, opts)
					--   require("typescript").setup({ server = opts })
					--   return true
					-- end,
					-- Specify * to use this function as a fallback for any server
					-- ["*"] = function(server, opts) end,
					--python
					ruff = function()
						GlobalUtil.lsp.on_attach(function(client, _)
							-- Disable hover in favor of Pyright
							client.server_capabilities.hoverProvider = false
						end, "ruff")
					end,
					--- @deprecated -- tsserver renamed to ts_ls but not yet released, so keep this for now
					--- the proper approach is to check the nvim-lspconfig release version when it's released to determine the server name dynamically
					-- jdtls 由 nvim-jdtls 插件独立管理，禁止 lspconfig 重复启动
					jdtls = function()
						return true
					end,
					tsserver = function()
						-- disable tsserver
						return true
					end,
					ts_ls = function()
						-- disable tsserver
						return true
					end,
					vtsls = function(_, opts)
						GlobalUtil.lsp.on_attach(function(client, buffer)
							client.commands["_typescript.moveToFileRefactoring"] = function(command, ctx)
								---@type string, string, lsp.Range
								local action, uri, range = unpack(command.arguments)

								local function move(newf)
									client.request("workspace/executeCommand", {
										command = command.command,
										arguments = { action, uri, range, newf },
									})
								end

								local fname = vim.uri_to_fname(uri)
								client.request("workspace/executeCommand", {
									command = "typescript.tsserverRequest",
									arguments = {
										"getMoveToRefactoringFileSuggestions",
										{
											file = fname,
											startLine = range.start.line + 1,
											startOffset = range.start.character + 1,
											endLine = range["end"].line + 1,
											endOffset = range["end"].character + 1,
										},
									},
								}, function(_, result)
									---@type string[]
									local files = result.body.files
									table.insert(files, 1, "Enter new path...")
									vim.ui.select(files, {
										prompt = "Select move destination:",
										format_item = function(f)
											return vim.fn.fnamemodify(f, ":~:.")
										end,
									}, function(f)
										if f and f:find("^Enter new path") then
											vim.ui.input({
												prompt = "Enter move destination:",
												default = vim.fn.fnamemodify(fname, ":h") .. "/",
												completion = "file",
											}, function(newf)
												return newf and move(newf)
											end)
										elseif f then
											move(f)
										end
									end)
								end)
							end
						end, "vtsls")
						-- copy typescript settings to javascript
						opts.settings.javascript =
							vim.tbl_deep_extend("force", {}, opts.settings.typescript, opts.settings.javascript or {})
					end,
				},
			}
			-- copilot LSP server 仅供 sidekick.nvim NES 功能使用。
			-- 默认禁用 mason-lspconfig 自动启动，避免与 copilot.lua 自身管理的进程冲突。
			local sidekick_opts = GlobalUtil.opts("sidekick.nvim") ---@type sidekick.Config|{}
			if GlobalUtil.has("sidekick.nvim") and vim.tbl_get(sidekick_opts, "nes", "enabled") ~= false then
				ret.servers.copilot = {}
			else
				ret.servers.copilot = { enabled = false }
			end
			return ret
		end,
		---@param opts PluginLspOpts
		config = vim.schedule_wrap(function(_, opts)
			-- setup autoformat
			GlobalUtil.format.register(GlobalUtil.lsp.formatter())

			-- setup keymaps
			GlobalUtil.lsp.on_attach(function(client, buffer)
				M.on_attach(client, buffer)
			end)

			GlobalUtil.lsp.setup()
			GlobalUtil.lsp.on_dynamic_capability(M.on_attach)

			-- inlay hints
			if opts.inlay_hints.enabled then
				GlobalUtil.lsp.on_supports_method("textDocument/inlayHint", function(client, buffer)

      -- 诊断：在 Python 下禁止 documentHighlight 避免高延迟
      GlobalUtil.lsp.on_supports_method("textDocument/documentHighlight", function(client, buffer)
        if vim.bo[buffer].filetype == "python" then
          client.server_capabilities.documentHighlightProvider = false
        end
      end)

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

			local exclude_automatic_enable = {} ---@type string[]

			local function configure(server)
				local server_opts = opts.servers[server] or {}

				local setup = opts.setup[server] or opts.setup["*"]
				if setup and setup(server, server_opts) then
					return true -- lsp will be setup by the setup function
				end

				vim.lsp.config(server, server_opts)

				-- manually enable if mason=false or if this is a server that cannot be installed with mason-lspconfig
				if server_opts.mason == false or not vim.tbl_contains(mason_all, server) then
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
						exclude_automatic_enable[#exclude_automatic_enable + 1] = server
					else
						ensure_installed[#ensure_installed + 1] = server
					end
				else
					exclude_automatic_enable[#exclude_automatic_enable + 1] = server
				end
			end

			if have_mason then
				require("mason-lspconfig").setup({
					ensure_installed = vim.tbl_deep_extend(
						"force",
						ensure_installed,
						GlobalUtil.opts("mason-lspconfig.nvim").ensure_installed or {}
					),
					automatic_enable = {
						exclude = exclude_automatic_enable,
					},
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
		end),
	},
	-- cmdline tools and lsp servers
	{
		"mason-org/mason.nvim",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		opts_extend = { "ensure_installed" },
		opts = {
        ensure_installed = {
          "stylua",
          "shfmt",
          "js-debug-adapter",
          "vue-language-server",
          "prettier",
          --"typescript-language-server",
          "jdtls",
          "google-java-format",
          "lua-language-server",
          "json-lsp",
          "vtsls",
          "basedpyright",
          "ruff",
          "taplo",
          "markdown-oxide",
        },
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			mr:on("package:install:success", function()
				vim.defer_fn(function()
					-- trigger FileType event to possibly load this newly installed LSP server
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)

			mr.refresh(function()
				for _, tool in ipairs(opts.ensure_installed) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						p:install()
					end
				end
			end)
		end,
	},

	-- none-ls
	{
		"nvimtools/none-ls.nvim",
		event = { "filetype", "BufReadPost", "BufNewFile", "BufWritePre" },
		dependencies = { "mason.nvim", "nvim-lua/plenary.nvim", "nvimtools/none-ls-extras.nvim" },
		init = function()
			GlobalUtil.on_very_lazy(function()
				-- register the formatter with LazyVim
				GlobalUtil.format.register({
					name = "none-ls.nvim",
					priority = 200, -- set higher than conform, the builtin formatter
					primary = true,
					format = function(buf)
						return GlobalUtil.lsp.format({
							bufnr = buf,
							filter = function(client)
								local has_null = false
								for _, c in ipairs(GlobalUtil.lsp.get_clients({ bufnr = buf })) do
									if c.name == "null-ls" then
										has_null = true
										break
									end
								end
								if has_null then
									return client.name == "null-ls"
								end
								return client:supports_method("textDocument/formatting")
							end,
						})
					end,
					sources = function(buf)
						local ret = require("null-ls.sources").get_available(vim.bo[buf].filetype, "NULL_LS_FORMATTING")
							or {}
						return vim.tbl_map(function(source)
							return source.name
						end, ret)
					end,
				})
			end)
		end,
		opts = function(_, opts)
			local nls = require("null-ls")
			opts.root_dir = opts.root_dir
				or require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git")
        opts.sources = vim.list_extend(opts.sources or {}, {
          nls.builtins.formatting.fish_indent,
          nls.builtins.diagnostics.fish,
          nls.builtins.formatting.stylua,
          nls.builtins.formatting.shfmt,
          nls.builtins.formatting.prettier.with({
            filetypes = {
              "javascript",
              "typescript",
              "typescriptreact",
              "javascriptreact",
              "json",
              "jsonc",
              "css",
              "scss",
              "markdown",
            },
          }),

        -- nls.builtins.formatting.prettier.with({
				-- 	-- 推荐只格式化你关心的文件类型
				-- 	filetypes = {
				-- 		"javascript",
				-- 		"typescript",
				-- 		"typescriptreact",
				-- 		"javascriptreact",
				-- 		"json",
				-- 		"css",
				-- 		"scss",
				-- 		"markdown",
				-- 	},
				-- }),
			})
		end,
	},
}

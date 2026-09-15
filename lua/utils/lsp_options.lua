local M = {}

-- 语言服务器设置集中维护；此函数在 lazy.setup 完成插件规格解析后执行。
function M.get()
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
			-- Vue 的 HTML/CSS 由 vue_ls 提供，脚本部分交给 vtsls。
			vue_ls = {},
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
					local ok, schemas = pcall(require, "schemastore")
					-- SchemaStore 为可选增强，缺失时保留 jsonls 自带验证。
					if ok then
						vim.list_extend(new_config.settings.json.schemas, schemas.json.schemas())
					end
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
							client:request("workspace/executeCommand", {
								command = command.command,
								arguments = { action, uri, range, newf },
							})
						end

						local fname = vim.uri_to_fname(uri)
						client:request("workspace/executeCommand", {
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
						}, function(err, result)
							if err or not (result and result.body and result.body.files) then
								GlobalUtil.warn(err and err.message or "未返回移动目标", { title = "vtsls" })
								return
							end
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
	-- Copilot 由 copilot.lua 管理，禁止 Mason 再启动同名服务。
	ret.servers.copilot = { enabled = false }
	return ret
end

return M

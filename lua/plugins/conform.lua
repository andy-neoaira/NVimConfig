-- 所有外部格式化统一由 Conform 调度，未配置工具时回退到 LSP。
-- Prettier 的项目命令查找、配置读取与范围格式化使用插件内置实现。
return {
	"stevearc/conform.nvim",
	dependencies = { "mason.nvim" },
	event = "BufWritePre",
	cmd = "ConformInfo",
	init = function()
		GlobalUtil.on_very_lazy(function()
			GlobalUtil.format.register({
				name = "conform.nvim",
				priority = 100,
				primary = true,
				format = function(buf)
					require("conform").format({ bufnr = buf })
				end,
				sources = function(buf)
					return vim.tbl_map(function(formatter)
						return formatter.name
					end, require("conform").list_formatters(buf))
				end,
			})
		end)
	end,
	opts = {
		default_format_opts = { timeout_ms = 3000, lsp_format = "fallback" },
		-- 保存必须同步完成格式化，避免文件写出后才修改缓冲区。
		format_on_save = function(buf)
			if not GlobalUtil.format.enabled(buf) or vim.bo[buf].buftype ~= "" or not vim.bo[buf].modifiable then
				return
			end
			return { timeout_ms = 1000, lsp_format = "fallback" }
		end,
		formatters_by_ft = {
			lua = { "stylua" },
			fish = { "fish_indent" },
			sh = { "shfmt" },
			css = { "prettier" },
			graphql = { "prettier" },
			handlebars = { "prettier" },
			html = { "prettier" },
			javascript = { "prettier" },
			javascriptreact = { "prettier" },
			json = { "prettier", "jq", stop_after_first = true },
			json5 = { "prettier" },
			jsonc = { "prettier" },
			less = { "prettier" },
			scss = { "prettier" },
			typescript = { "prettier" },
			typescriptreact = { "prettier" },
			vue = { "prettier" },
			yaml = { "prettier" },
			markdown = { "prettier", "markdownlint-cli2", "markdown-toc" },
			["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
			java = { "google-java-format" },
		},
		formatters = {
			["markdown-toc"] = {
				condition = function(_, ctx)
					for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
						if line:find("<!-- toc -->", 1, true) then
							return true
						end
					end
					return false
				end,
			},
			["google-java-format"] = function(buf)
				local args = {}
				local root =
					vim.fs.root(buf, { ".nvim/java.json", "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
				local config = root and (root .. "/.nvim/java.json")
				if config and vim.fn.filereadable(config) == 1 then
					local ok, data = pcall(function()
						return vim.json.decode(table.concat(vim.fn.readfile(config), "\n"))
					end)
					if ok and type(data) == "table" and type(data.google_java_format) == "table" then
						if data.google_java_format.aosp == true then
							args[#args + 1] = "--aosp"
						end
					elseif not ok then
						vim.notify_once("Java 格式化配置读取失败: " .. tostring(data), vim.log.levels.WARN)
					end
				end
				-- google-java-format 不支持任意行宽；保留其官方 Google/AOSP 风格。
				if vim.fn.executable("google-java-format") == 1 then
					args[#args + 1] = "-"
					return { command = "google-java-format", args = args, stdin = true }
				end
				local jar = vim.env.GOOGLE_JAVA_FORMAT_JAR
				if not jar or jar == "" then
					local dir = GlobalUtil.get_pkg_path("google-java-format", "", { warn = false })
					jar = vim.fn.globpath(dir, "*.jar", false, true)[1]
				end
				if jar and vim.fn.filereadable(jar) == 1 and vim.fn.executable("java") == 1 then
					return {
						command = "java",
						args = vim.list_extend({ "-jar", jar }, vim.list_extend(args, { "-" })),
						stdin = true,
					}
				end
				-- 保留内置命令，让 Conform 标记工具不可用并执行 LSP 回退。
				return { command = "google-java-format" }
			end,
		},
	},
}

-- Java LSP 默认为关闭（保留原配置选择）；启用前设置 vim.g.java_lsp = true。
-- jdtls 由此插件独立管理，Mason-LSP 不重复启动；仅打开 Java 文件时初始化。
return {
	"mfussenegger/nvim-jdtls",
	enabled = function()
		return vim.g.java_lsp == true
	end,
	ft = "java",
	dependencies = { "mason.nvim" },
	opts = { maven_offline = false },
	config = function(_, opts)
		local jdtls = require("jdtls")
		local function attach(buf)
			if vim.bo[buf].buftype ~= "" then
				return
			end
			local root = vim.fs.root(buf, { "gradlew", "mvnw", ".git" })
				or vim.fs.root(buf, { "pom.xml", "build.gradle", "build.gradle.kts" })
				or vim.fn.getcwd()
			local project = {}
			local file = root .. "/.nvim/java.json"
			if vim.fn.filereadable(file) == 1 then
				local ok, data = pcall(function()
					return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
				end)
				if not ok or type(data) ~= "table" then
					GlobalUtil.warn("Java 项目配置读取失败: " .. file)
					return
				end
				project = data
			end
			local jdk = opts.jdtls_jdk or vim.env.JAVA_HOME
			local java = jdk and (jdk .. "/bin/java") or vim.fn.exepath("java")
			if not java or vim.fn.executable(java) ~= 1 then
				GlobalUtil.warn("jdtls 需要 JDK 21+，请配置 JAVA_HOME 或 jdtls_jdk")
				return
			end
			local dir = GlobalUtil.get_pkg_path("jdtls", "", { warn = false })
			local launcher = vim.fn.globpath(dir, "plugins/org.eclipse.equinox.launcher_*.jar", false, true)[1]
			if not launcher then
				GlobalUtil.warn("jdtls 未安装，请通过 :ToolsInstall 或 :Mason 安装")
				return
			end
			local platform = vim.fn.has("macunix") == 1 and "mac" or vim.fn.has("win32") == 1 and "win" or "linux"
			-- 新版 Mason 包可能区分 ARM；按实际目录选择配置，不硬编码 mac。
			local config_dir = dir .. "/config_" .. platform
			if vim.uv.os_uname().machine:match("arm") or vim.uv.os_uname().machine == "aarch64" then
				if vim.fn.isdirectory(config_dir .. "_arm") == 1 then
					config_dir = config_dir .. "_arm"
				end
			end
			local cmd = {
				java,
				"-Dfile.encoding=UTF-8",
				"-Xms256m",
				"-Xmx2048m",
				"--add-opens",
				"java.base/java.util=ALL-UNNAMED",
				"--add-opens",
				"java.base/java.lang=ALL-UNNAMED",
			}
			local lombok = project.lombok_jar or opts.lombok_jar
			if not lombok then
				lombok =
					vim.fn.globpath(GlobalUtil.get_pkg_path("lombok", "", { warn = false }), "*.jar", false, true)[1]
			end
			if lombok and vim.fn.filereadable(lombok) == 1 then
				cmd[#cmd + 1] = "-javaagent:" .. lombok
			end
			-- 同名项目使用完整根路径的哈希区分，防止 workspace 索引相互污染。
			local workspace = vim.fn.stdpath("data")
				.. "/jdtls/workspace/"
				.. vim.fn.fnamemodify(root, ":t")
				.. "-"
				.. vim.fn.sha256(root):sub(1, 12)
			vim.list_extend(cmd, { "-jar", launcher, "-configuration", config_dir, "-data", workspace })
			local offline = project.maven_offline
			if offline == nil then
				offline = opts.maven_offline
			end
			local project_jdk = project.project_jdk or vim.env.JAVA_HOME
			local caps = vim.lsp.protocol.make_client_capabilities()
			local ok, blink = pcall(require, "blink.cmp")
			if ok then
				caps = blink.get_lsp_capabilities(caps)
			end
			vim.api.nvim_buf_call(buf, function()
				jdtls.start_or_attach({
					cmd = cmd,
					root_dir = root,
					capabilities = caps,
					init_options = { bundles = {} },
					settings = {
						java = {
							import = {
								maven = {
									java = { home = project_jdk },
									userSettings = project.maven_settings or opts.maven_settings,
									globalSettings = project.maven_global_settings or opts.maven_global_settings,
									offline = offline,
								},
								gradle = { java = { home = project_jdk } },
							},
						},
					},
				})
			end)
		end
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("custom_jdtls", { clear = true }),
			pattern = "java",
			callback = function(ev)
				attach(ev.buf)
			end,
		})
		if vim.bo.filetype == "java" then
			attach(vim.api.nvim_get_current_buf())
		end
	end,
}

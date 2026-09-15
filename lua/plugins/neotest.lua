return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
			"marilari88/neotest-vitest",
		},
		opts = {
			adapters = {
				-- 配置Pyton pytest测试框架
				["neotest-python"] = {
					runner = "pytest",
					-- 每次运行按项目解析解释器，避免写死当前目录的 .venv。
					python = function(root)
						return require("utils.python").resolve(root)
					end,
					-- 参数
					args = { "--log-level", "DEBUG", "-s" },
					-- is_test_file = function(file_path)
					-- 	-- 判断项目根目录是否有 pyproject.toml
					-- 	if vim.fn.filereadable("./pyproject.toml") == 0 then
					-- 		return false
					-- 	end
					-- 	-- 读取 pyproject.toml 内容
					-- 	local pyproject_lines = vim.fn.readfile("./pyproject.toml")
					-- 	local pyproject_str = table.concat(pyproject_lines, "\n")
					-- 	-- 可根据实际情况加强判断，比如检测 pytest、poetry、flit 等配置段
					-- 	local is_python_project = pyproject_str:match("%[tool%.pytest%.ini_options%]")
					-- 		or pyproject_str:match("%[tool%.poetry%]")
					-- 		or pyproject_str:match("%[project%]")
					--
					-- 	-- 判断是否是 Python 测试文件
					-- 	local is_py_test_file = file_path:match("test_.*%.py$") or file_path:match(".*_test%.py$")
					-- 	return is_python_project and is_py_test_file
					-- end,
				},
				--vitest 配置
				["neotest-vitest"] = {
					filter_dir = function(name, rel_path, root)
						return name ~= "node_modules"
					end,
					-- is_test_file = function(file_path)
					-- 	-- 只有有 vitest 依赖时才启用
					-- 	return vim.fn.filereadable("./package.json") == 1
					-- 		and string.match(vim.fn.readfile("./package.json"), '"vitest"')
					-- 		and file_path:match("%.test%.ts$")
					-- end,
				},
			},
			status = { virtual_text = true },
			output = { open_on_run = true },
			quickfix = {
				open = function()
					if GlobalUtil.has("trouble.nvim") then
						require("trouble").open({ mode = "quickfix", focus = false })
					else
						vim.cmd("copen")
					end
				end,
			},
		},
		config = function(_, opts)
			local neotest_ns = vim.api.nvim_create_namespace("neotest")
			vim.diagnostic.config({
				virtual_text = {
					format = function(diagnostic)
						-- Replace newline and tab characters with space for more compact diagnostics
						local message =
							diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
						return message
					end,
				},
			}, neotest_ns)

			if GlobalUtil.has("trouble.nvim") then
				opts.consumers = opts.consumers or {}
				-- Refresh and auto close trouble after running tests
				opts.consumers.trouble = function(client)
					client.listeners.results = function(adapter_id, results, partial)
						if partial then
							return
						end
						local tree = client:get_position(nil, { adapter = adapter_id })
						if not tree then
							return
						end

						local failed = 0
						for pos_id, result in pairs(results) do
							if result.status == "failed" and tree:get_key(pos_id) then
								failed = failed + 1
							end
						end
						vim.schedule(function()
							local trouble = require("trouble")
							if trouble.is_open({ mode = "quickfix" }) then
								trouble.refresh({ mode = "quickfix" })
								if failed == 0 then
									trouble.close({ mode = "quickfix" })
								end
							end
						end)
						return {}
					end
				end
			end

			if opts.adapters then
				local adapters = {}
				for name, config in pairs(opts.adapters or {}) do
					if type(name) == "number" then
						if type(config) == "string" then
							config = require(config)
						end
						adapters[#adapters + 1] = config
					elseif config ~= false then
						local adapter = require(name)
						if type(config) == "table" and not vim.tbl_isempty(config) then
							local meta = getmetatable(adapter)
							if adapter.setup then
								adapter.setup(config)
							elseif adapter.adapter then
								adapter.adapter(config)
								adapter = adapter.adapter
							elseif meta and meta.__call then
								adapter = adapter(config)
							else
								error("Adapter " .. name .. " does not support setup")
							end
						end
						adapters[#adapters + 1] = adapter
					end
				end
				opts.adapters = adapters
			end

			require("neotest").setup(opts)
		end,
  -- stylua: ignore
  keys = {
    {"<leader>t", "", desc = "+test"},
    { "<leader>tt", function() require("neotest").run.run() end, desc = "Run Nearest (Neotest)" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File (Neotest)" },
    { "<leader>tF", function() require("neotest").run.run(vim.uv.cwd()) end, desc = "Run All Test Files (Neotest)" },
    -- { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run Last (Neotest)" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary (Neotest)" },
    { "<leader>to", function() require("neotest").output.open({ short=false,enter = true, auto_close = true }) end, desc = "Show Output (Neotest)" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel (Neotest)" },
    { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop (Neotest)" },
    { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Toggle Watch (Neotest)" },
  },
	},
}

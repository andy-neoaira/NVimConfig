local M = {}

-- Load all .scm query files under given directory.
-- Expected layout: <dir>/<lang>/*.scm
-- For each file, call require('nvim-treesitter.query').set_query(lang, group, content)
-- path may be absolute or contain ~; this function expands it.
---@param dir string
function M.load_dir(dir)
	if not dir or dir == "" then
		return
	end
	local path = vim.fn.expand(dir)
	if vim.fn.isdirectory(path) == 0 then
		return
	end

	-- 使用 Neovim 内置 API；新版 nvim-treesitter 不再提供 query.set_query。
	local ts_query = vim.treesitter.query

	-- glob for files like /path/lang/group.scm
	local files = vim.fn.globpath(path, "*/*.scm", true, true)
	for _, f in ipairs(files) do
		-- extract lang and group name
		-- pattern: /.../<lang>/<group>.scm
		local lang, group = string.match(f, vim.pesc(path) .. "/([^/]+)/([^/]+)%.scm$")
		if not lang then
			-- fallback: try generic capture
			lang, group = string.match(f, ".*/([^/]+)/([^/]+)%.scm$")
		end
		if lang and group then
			-- 每个查询单独处理，错误应指出具体文件，不中断其他语言的加载。
			local ok, err = pcall(function()
				local content = table.concat(vim.fn.readfile(f), "\n")
				ts_query.set(lang, group, content)
			end)
			if not ok then
				GlobalUtil.warn("查询加载失败: " .. f .. "\n" .. tostring(err))
			end
		end
	end
end

return M

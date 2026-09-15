local M = {}

--- 不缓存解释器：切换项目或激活虚拟环境后立即生效。
---@param root? string
---@return string
function M.resolve(root)
	root = root or GlobalUtil.root.get()
	local suffix = vim.fn.has("win32") == 1 and "/Scripts/python.exe" or "/bin/python"
	local candidates = {}
	if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
		candidates[#candidates + 1] = vim.env.VIRTUAL_ENV .. suffix
	end
	for _, name in ipairs({ ".venv", "venv" }) do
		candidates[#candidates + 1] = root .. "/" .. name .. suffix
	end
	for _, path in ipairs(candidates) do
		if vim.fn.executable(path) == 1 then
			return path
		end
	end
	for _, name in ipairs({ "python3", "python" }) do
		local path = vim.fn.exepath(name)
		if path ~= "" then
			return path
		end
	end
	return "python3"
end

return M

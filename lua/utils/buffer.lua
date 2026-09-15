---@class utils.buffer
local M = {}
local saving = {}
local pending = {}

--- 普通模式连续编辑时合并写盘；重新进入插入模式后等待 InsertLeave 保存。
---@param buf integer
function M.schedule_autosave(buf)
	local token = {}
	pending[buf] = token
	vim.defer_fn(function()
		if pending[buf] ~= token then
			return
		end
		pending[buf] = nil
		if vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_mode().mode:match("^[iR]") then
			return
		end
		M.autosave(buf)
	end, 200)
end

--- 自动保存不处理特殊缓冲区、URI、只读文件或未命名草稿。
--- 使用目标缓冲区上下文，避免后台事件误写当前窗口的文件。
---@param buf integer
---@return boolean saved
function M.autosave(buf)
	pending[buf] = nil
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) or saving[buf] then
		return false
	end
	local bo = vim.bo[buf]
	local name = vim.api.nvim_buf_get_name(buf)
	if
		not bo.modified
		or not bo.modifiable
		or bo.readonly
		or bo.buftype ~= ""
		or name == ""
		or name:match("^%a[%w+.-]*://")
		or vim.g.autosave == false
		or vim.b[buf].autosave == false
	then
		return false
	end
	saving[buf] = true
	local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
		vim.cmd("silent update")
	end)
	saving[buf] = nil
	if not ok then
		-- 写入失败必须可见，保留 modified 状态供手动重试。
		vim.notify_once("自动保存失败: " .. tostring(err), vim.log.levels.WARN)
	end
	return ok
end

return M

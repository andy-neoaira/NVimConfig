---@class utils.ui
--- UI 相关工具函数模块
--- 提供折叠、窗口管理等 UI 功能
local M = {}

--- 注意：close() 内置健壮性处理，在缺少 Snacks 时自动回退到内置 bdelete

--- 优化的 Treesitter 折叠表达式
--- 使用 Neovim 内置 Treesitter 折叠，不维护容易过期的解析器缓存。
--- @return string 返回折叠级别字符串
---
function M.foldexpr()
	-- 内置实现会处理无解析器的情况，不缓存失败以便安装解析器后恢复。
	return vim.treesitter.foldexpr()
end

--- 智能关闭缓冲区或窗口
--- 根据缓冲区类型和窗口数量智能决定关闭行为：
--- - 对于特殊缓冲区（如帮助、终端等），直接关闭窗口
--- - 对于普通缓冲区：
---   - 如果在多个窗口中打开，只关闭当前窗口
---   - 如果只在当前窗口打开，关闭缓冲区
---   - 删除成功且还有其他普通窗口时，关闭空出的分屏
---
function M.close()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_get_current_buf()
	local current_buftype = vim.bo[current_buf].buftype

	-- 特殊类型的缓冲区（如帮助、终端等），直接关闭窗口
	if current_buftype ~= "" then
		vim.cmd([[q]])
		return
	end

	-- 统计窗口信息
	local current_buf_win_count = 0 -- 当前缓冲区打开的窗口数
	local normal_buf_win_count = 0 -- 所有普通缓冲区的窗口总数

	local all_wins = vim.api.nvim_list_wins()
	for _, win in ipairs(all_wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		local buftype = vim.bo[buf].buftype

		if buftype == "" then
			normal_buf_win_count = normal_buf_win_count + 1
			if buf == current_buf then
				current_buf_win_count = current_buf_win_count + 1
			end
		end
	end

	-- 决定关闭行为
	if current_buf_win_count > 1 then
		-- 当前缓冲区在多个窗口中打开，只关闭当前窗口
		vim.api.nvim_win_close(current_win, false)
	elseif current_buf_win_count == 1 then
		-- 当前缓冲区只在当前窗口打开
		-- 关闭缓冲区
		-- 安全删除缓冲区：优先使用 Snacks.bufdelete，不存在则回退到内置命令
		if GlobalUtil.has("snacks.nvim") and pcall(require, "snacks") then
			Snacks.bufdelete(current_buf)
		else
			-- 回退路径同样保护未保存修改，不使用强制删除。
			local ok, err = pcall(vim.cmd.bdelete, { current_buf })
			if not ok then
				GlobalUtil.warn(tostring(err), { title = "关闭缓冲区" })
				return
			end
		end

		-- 如果还有其他普通窗口，也关闭当前窗口
		-- Snacks 的取消操作没有返回值，通过原缓冲区是否仍列出判断结果。
		local deleted = not vim.api.nvim_buf_is_valid(current_buf) or not vim.bo[current_buf].buflisted
		if deleted and normal_buf_win_count > 1 and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_win_close(current_win, false)
		end
	end
end

return M

local M = {}

--- 串行执行 Hammerspoon IPC，仅保留最后一次待执行操作。
--- 防止快速切换插入/普通模式时，较旧进程最后完成并覆盖新的输入法状态。
function M.setup()
	if
		vim.g.input_method == false
		or vim.fn.has("macunix") == 0
		or vim.fn.executable("hs") == 0
		or #vim.api.nvim_list_uis() == 0
	then
		return
	end
	local english = vim.g.english_input_method or "com.apple.keylayout.ABC"
	local previous, pending, running
	local pump
	pump = function()
		if running or not pending then
			return
		end
		local action = pending
		pending = nil
		local target = action == "restore" and previous or english
		if not target then
			return
		end
		local script = string.format(
			'local current = hs.keycodes.currentSourceID(); print("NVIM_INPUT_METHOD:" .. (current or "")); if current ~= %q then hs.keycodes.currentSourceID(%q) end',
			target,
			target
		)
		running = true
		local ok, err = pcall(vim.system, { "hs", "-c", script }, { text = true, timeout = 2000 }, function(result)
			vim.schedule(function()
				running = false
				if result.code == 0 then
					local current = (result.stdout or ""):match("NVIM_INPUT_METHOD:([^\r\n]+)")
					if action == "remember" and current and current ~= english then
						previous = current
					end
				else
					vim.notify_once(
						"Hammerspoon 输入法切换失败，请检查 hs CLI 和 Hammerspoon 是否运行",
						vim.log.levels.WARN
					)
				end
				pump()
			end)
		end)
		if not ok then
			running = false
			vim.notify_once("无法启动 Hammerspoon CLI: " .. tostring(err), vim.log.levels.WARN)
		end
	end
	local function request(action)
		pending = action
		pump()
	end
	local function in_insert_mode()
		return vim.api.nvim_get_mode().mode:match("^[iR]") ~= nil
	end
	local group = vim.api.nvim_create_augroup("custom_input_method", { clear = true })
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			request("remember")
		end,
	})
	vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "CmdlineEnter" }, {
		group = group,
		callback = function()
			if not in_insert_mode() then
				request("english")
			end
		end,
	})
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			local col = vim.api.nvim_win_get_cursor(0)[2]
			local before = vim.api.nvim_get_current_line():sub(1, col)
			local char = vim.fn.strcharpart(before, vim.fn.strchars(before) - 1, 1)
			-- 队列中的 restore 在前一次读取完成后才求值，首次使用也能恢复中文输入法。
			request(char ~= "" and char:byte() > 127 and "restore" or "english")
		end,
	})
end

return M

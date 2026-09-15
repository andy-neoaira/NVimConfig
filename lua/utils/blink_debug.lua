local M = {}

--- 通过事件记录补全诊断，不覆盖 LSP 请求函数或补全引擎内部方法。
function M.setup()
	local logfile = vim.fn.stdpath("log") .. "/blink_diag.log"
	local pending = {}
	local group = vim.api.nvim_create_augroup("custom_blink_debug", { clear = true })
	local function log(message)
		local ok, err = pcall(vim.fn.writefile, { os.date("%H:%M:%S ") .. message }, logfile, "a")
		if not ok then
			vim.notify_once("补全诊断日志写入失败: " .. tostring(err), vim.log.levels.WARN)
		end
	end
	vim.api.nvim_create_autocmd("LspRequest", {
		group = group,
		callback = function(ev)
			local data = ev.data
			local key = data.client_id .. ":" .. data.request_id
			if data.request.type == "pending" then
				pending[key] = vim.uv.hrtime()
			elseif pending[key] then
				log(
					("LSP %s %.1fms client=%d %s"):format(
						data.request.method or "?",
						(vim.uv.hrtime() - pending[key]) / 1e6,
						data.client_id,
						data.request.type
					)
				)
				pending[key] = nil
			end
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "BlinkCmpMenuOpen", "BlinkCmpMenuClose" },
		callback = function(ev)
			log(ev.match)
		end,
	})
	log("补全诊断已启动")
end

return M

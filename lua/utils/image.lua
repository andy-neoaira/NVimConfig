-- Snacks 当前版本缺少文档图片开关，兼容适配集中在此模块。
-- 升级 lazy-lock 中的 Snacks 后需复核 inline.new/update、doc.find_visible 与 placement.update。
local M = { enabled = true }
local instances = {}

function M.setup()
	if M._setup then
		return
	end
	M._setup = true
	local inline = require("snacks.image.inline")
	local doc = require("snacks.image.doc")
	local placement = require("snacks.image.placement")
	local new, update, conceal = inline.new, inline.update, inline.conceal
	inline.new = function(buf)
		-- 同一缓冲区复用实例，避免开关预览时重复注册 on_lines 回调。
		if instances[buf] then
			return instances[buf]
		end
		local instance = new(buf)
		instances[buf] = instance
		return instance
	end
	inline.update = function(self)
		if not vim.api.nvim_buf_is_valid(self.buf) then
			return
		end
		if not M.enabled then
			for _, img in pairs(self.imgs) do
				img:close()
			end
			self.imgs, self.idx = {}, {}
			return
		end
		return update(self)
	end
	inline.conceal = function(self)
		if not M.enabled then
			return inline.update(self)
		end
		return conceal(self)
	end
	local find_visible = doc.find_visible
	local hover = doc.hover
	doc.hover = function(...)
		if not M.enabled then
			return doc.hover_close()
		end
		return hover(...)
	end
	doc.find_visible = function(buf, callback)
		if not M.enabled then
			return callback({})
		end
		return find_visible(buf, function(imgs)
			-- 关闭后才返回的异步解析结果也不能重新显示图片。
			callback(M.enabled and imgs or {})
		end)
	end
	local placement_update = placement.update
	placement.update = function(self)
		if not self.opts.inline and self.hidden and #self:wins() > 0 then
			self.hidden = false
		end
		local ok, err = pcall(placement_update, self)
		if not ok then
			if tostring(err):find("Not a valid PNG", 1, true) then
				vim.notify_once("无法显示损坏的 PNG 图片", vim.log.levels.WARN)
				return
			end
			error(err, 2)
		end
	end
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = vim.api.nvim_create_augroup("custom_image_instances", { clear = true }),
		callback = function(ev)
			instances[ev.buf] = nil
		end,
	})
end

---@param enabled boolean
function M.set_enabled(enabled)
	M.enabled = enabled
	local doc = require("snacks.image.doc")
	doc.hover_close()
	for buf, instance in pairs(instances) do
		if vim.api.nvim_buf_is_valid(buf) then
			instance:update()
		else
			instances[buf] = nil
		end
	end
end

function M.toggle_markdown()
	local markdown = require("render-markdown")
	markdown.toggle()
	M.set_enabled(markdown.get())
end

return M

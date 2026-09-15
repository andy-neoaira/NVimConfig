return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {
		-- 至少打开 1 个文件 buffer 才保存 session（避免保存空会话）
		need = 1,
		-- 按 git branch 区分 session，同一项目不同分支独立保存
		branch = true,
	},
	-- stylua: ignore
	keys = {
		{ "<leader>Ss", function() require("persistence").load() end,                desc = "恢复当前目录 Session" },
		{ "<leader>SS", function() require("persistence").select() end,              desc = "选择 Session" },
		{ "<leader>Sl", function() require("persistence").load({ last = true }) end, desc = "恢复上次 Session" },
		{ "<leader>Sd", function() require("persistence").stop() end,                desc = "本次退出不保存 Session" },
	},
	-- 会话保存不得删除活动终端、临时内容或未保存缓冲区。
	-- 普通会话过滤交由 sessionoptions；need 防止空会话覆盖已有记录。
}

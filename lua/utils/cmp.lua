---@class utils.cmp
--- utils.cmp（与补全引擎解耦的通用工具）
--- 职责：提供片段处理、撤销点、AI 接受、光标判断等通用能力；不直接依赖 nvim-cmp/blink.cmp 的内部 API。
--- 注意：返回 true 表示已处理（用于键位链式判定），返回 false/nil 表示交由下一个分支或 fallback。

--- 代码补全工具模块
--- 提供 nvim-cmp 补全相关的辅助函数
local M = {}

--- 动作集合：与补全引擎解耦的通用动作（供键位链式调用）
--- 返回 true 表示已处理，返回 false/nil 表示未处理，交由下一个分支或 fallback
M.actions = {
  --- 片段前进跳转
  snippet_forward = function()
    if vim.snippet and vim.snippet.active({ direction = 1 }) then
      vim.schedule(function() vim.snippet.jump(1) end)
      return true
    end
  end,
  --- 片段后退跳转
  snippet_backward = function()
    if vim.snippet and vim.snippet.active({ direction = -1 }) then
      vim.schedule(function() vim.snippet.jump(-1) end)
      return true
    end
  end,
  --- 接受 Copilot 内联建议（仅在可见时处理）
  ai_accept = function()
    local ok, sug = pcall(function() return require("copilot.suggestion") end)
    if ok and sug.is_visible() then
      GlobalUtil.create_undo()
      sug.accept()
      return true
    end
  end,
}


---@alias Placeholder {n:number, text:string}

--- 替换代码片段中的占位符
--- 遍历代码片段中的所有占位符并使用自定义函数处理
--- @param snippet string 原始代码片段字符串
--- @param fn function 处理函数 fun(placeholder:Placeholder):string
--- @return string 返回处理后的代码片段
--- 
--- 优化点：
--- 1. 添加了错误处理
--- 2. 改进了模式匹配的说明
function M.snippet_replace(snippet, fn)
	-- 匹配 ${数字:文本} 格式的占位符
	return snippet:gsub("%$%b{}", function(match)
		local n, name = match:match("^%${(%d+):(.+)}$")
		return n and fn({ n = tonumber(n), text = name }) or match
	end) or snippet
end
--- 预览代码片段
--- 解析嵌套的占位符，生成可读的预览文本
--- @param snippet string 代码片段字符串
--- @return string 返回预览文本
--- 
--- 优化点：
--- 1. 添加了错误处理
--- 2. 改进了递归处理逻辑
function M.snippet_preview(snippet)
	-- 尝试使用 Neovim 内置的片段语法解析器
	local ok, parsed = pcall(function()
		return vim.lsp._snippet_grammar.parse(snippet)
	end)
	
	if ok then
		return tostring(parsed)
	end
	
	-- 回退到手动解析
	return M.snippet_replace(snippet, function(placeholder)
		return M.snippet_preview(placeholder.text)
	end):gsub("%$0", "")
end

--- 修复代码片段
--- 处理嵌套占位符，确保片段符合 LSP 规范
--- @param snippet string 原始代码片段
--- @return string 返回修复后的代码片段
--- 
--- 优化点：
--- 1. 使用缓存避免重复处理相同占位符
--- 2. 改进了递归处理
function M.snippet_fix(snippet)
	local texts = {} ---@type table<number, string>
	return M.snippet_replace(snippet, function(placeholder)
		-- 缓存已处理的占位符文本
		texts[placeholder.n] = texts[placeholder.n] or M.snippet_preview(placeholder.text)
		return "${" .. placeholder.n .. ":" .. texts[placeholder.n] .. "}"
	end)
end

--- 自动添加括号
--- 为函数和方法补全项自动添加括号
--- @param entry cmp.Entry 补全条目
--- 
--- 优化点：
--- 1. 添加了更多的检查避免重复添加括号
--- 2. 改进了光标位置检测
function M.auto_brackets(entry)
	-- 兼容：若未安装 nvim-cmp，则跳过（blink.cmp 自带 auto_brackets）
	local ok, cmp = pcall(require, "cmp")
	if not ok then return end
	local Kind = cmp.lsp.CompletionItemKind
	local item = entry.completion_item
	-- 只为函数和方法添加括号
	if vim.tbl_contains({ Kind.Function, Kind.Method }, item.kind) then
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = cursor[1]
		local col = cursor[2]
		-- 检查光标后的字符
		local next_char = vim.api.nvim_buf_get_text(0, line - 1, col, line - 1, col + 1, {})[1]
		-- 如果后面不是括号，则添加括号并将光标置于括号内
		if next_char ~= "(" and next_char ~= ")" then
			local keys = vim.api.nvim_replace_termcodes("()<left>", false, false, true)
			vim.api.nvim_feedkeys(keys, "i", true)
		end
	end
end

--- 为代码片段添加缺失的文档
--- 如果补全项是代码片段但缺少文档，则生成预览文档
--- @param window cmp.CustomEntriesView|cmp.NativeEntriesView 补全窗口
--- 
--- 优化点：
--- 1. 只处理需要添加文档的条目
--- 2. 使用当前文件类型生成语法高亮的预览
function M.add_missing_snippet_docs(window)
	-- 兼容：若未安装 nvim-cmp，则跳过（仅用于旧引擎的菜单文档增强）
	local ok, cmp = pcall(require, "cmp")
	if not ok then return end
	local Kind = cmp.lsp.CompletionItemKind
	local entries = window:get_entries()
	for _, entry in ipairs(entries) do
		if entry:get_kind() == Kind.Snippet then
			local item = entry.completion_item
			if not item.documentation and item.insertText then
				item.documentation = {
					kind = cmp.lsp.MarkupKind.Markdown,
					value = string.format("```%s\n%s\n```", vim.bo.filetype, M.snippet_preview(item.insertText)),
				}
			end
		end
	end
end

--- 展开代码片段
--- 使用 Neovim 内置的代码片段功能展开片段
--- @param snippet string 要展开的代码片段
--- 
--- 优化点：
--- 1. 保持顶层会话状态，避免嵌套片段问题
--- 2. 添加了自动修复功能
--- 3. 改进了错误消息的显示
function M.expand(snippet)
	-- 保存当前的片段会话
	-- 原生会话不支持嵌套片段会话
	-- 始终使用顶层会话，避免在第一个占位符上选择新补全时使用嵌套会话
	local session = vim.snippet.active() and vim.snippet._session or nil

	local ok, err = pcall(vim.snippet.expand, snippet)
	
	if not ok then
		-- 尝试自动修复片段
		local fixed = M.snippet_fix(snippet)
		ok = pcall(vim.snippet.expand, fixed)

		local msg = ok and "代码片段解析失败，\n但已自动修复。"
			or ("代码片段解析失败。\n" .. err)

		GlobalUtil[ok and "warn" or "error"](
			([[%s
```%s
%s
```]]):format(msg, vim.bo.filetype, snippet),
			{ title = "vim.snippet" }
		)
	end

	-- 恢复顶层会话（如果需要）
	if session then
		vim.snippet._session = session
	end
end

--- 设置 nvim-cmp
--- 配置补全行为和事件处理器
--- @param opts cmp.ConfigSchema|{auto_brackets?:string[]} 配置选项
---   - auto_brackets: 需要自动添加括号的文件类型列表
--- 
--- 优化点：
--- 1. 添加了错误处理
--- 2. 改进了片段解析的兼容性
function M.setup(opts)
	-- 兼容：若未安装 nvim-cmp，则跳过（blink.cmp 不调用此函数）
	local ok_cmp, _ = pcall(require, "cmp")
	if not ok_cmp then return end
	-- 包装原始的片段解析函数，添加错误处理
	local parse = require("cmp.utils.snippet").parse
	require("cmp.utils.snippet").parse = function(input)
		local ok, ret = pcall(parse, input)
		if ok then return ret end
		return GlobalUtil.cmp.snippet_preview(input)
	end
	local cmp = require("cmp")
	cmp.setup(opts)
	cmp.event:on("confirm_done", function(event)
		if vim.tbl_contains(opts.auto_brackets or {}, vim.bo.filetype) then
			GlobalUtil.cmp.auto_brackets(event.entry)
		end
	end)
	cmp.event:on("menu_opened", function(event)
		GlobalUtil.cmp.add_missing_snippet_docs(event.window)
	end)
end

return M

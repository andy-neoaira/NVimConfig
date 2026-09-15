---@class utils.cmp
--- utils.cmp（与补全引擎解耦的通用工具）
--- 职责：提供片段处理、撤销点、AI 接受、光标判断等通用能力；不直接依赖 nvim-cmp/blink.cmp 的内部 API。
--- 注意：返回 true 表示已处理（用于键位链式判定），返回 false/nil 表示交由下一个分支或 fallback。

--- 代码补全工具模块
--- 提供原生 snippet 的展开与容错。
local M = {}

--- Python 符号适度加分，避免同名小写模块挤掉 ChatDeepSeek 等类。
--- 保留匹配分数主导排序，不改变候选文本或 LSP 的导入编辑。
---@param ctx {bufnr: integer}
---@param items table[]
---@return table[]
function M.rank_lsp_items(ctx, items)
	if not vim.api.nvim_buf_is_valid(ctx.bufnr) or vim.bo[ctx.bufnr].filetype ~= "python" then
		return items
	end
	local kinds = vim.lsp.protocol.CompletionItemKind
	local symbols = {
		[kinds.Class] = true,
		[kinds.Constructor] = true,
		[kinds.Function] = true,
		[kinds.Method] = true,
		[kinds.Variable] = true,
		[kinds.Field] = true,
		[kinds.Property] = true,
		[kinds.Constant] = true,
		[kinds.Enum] = true,
		[kinds.EnumMember] = true,
	}
	return vim.tbl_map(function(item)
		if not symbols[item.kind] then
			return item
		end
		-- 浅复制避免重复处理缓存候选时累计加分。
		local ranked = vim.tbl_extend("force", {}, item)
		ranked.score_offset = (item.score_offset or 0) + 12
		return ranked
	end, items)
end

--- 动作集合：与补全引擎解耦的通用动作（供键位链式调用）
--- 返回 true 表示已处理，返回 false/nil 表示未处理，交由下一个分支或 fallback
M.actions = {
	--- 片段前进跳转
	snippet_forward = function()
		if vim.snippet and vim.snippet.active({ direction = 1 }) then
			vim.schedule(function()
				vim.snippet.jump(1)
			end)
			return true
		end
	end,
	--- 片段后退跳转
	snippet_backward = function()
		if vim.snippet and vim.snippet.active({ direction = -1 }) then
			vim.schedule(function()
				vim.snippet.jump(-1)
			end)
			return true
		end
	end,
	--- 接受 Copilot 内联建议（仅在可见且非 Markdown 时处理）
	ai_accept = function()
		if vim.bo.filetype == "markdown" then
			return
		end
		local ok, suggestion = pcall(require, "copilot.suggestion")
		if ok and suggestion.is_visible() then
			GlobalUtil.create_undo()
			suggestion.accept()
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
function M.snippet_preview(snippet)
	-- 尝试使用 Neovim 内置的片段语法解析器
	local ok, parsed = pcall(function()
		return vim.lsp._snippet_grammar.parse(snippet)
	end)

	if ok and parsed then
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
function M.snippet_fix(snippet)
	local texts = {} ---@type table<number, string>
	return M.snippet_replace(snippet, function(placeholder)
		-- 缓存已处理的占位符文本
		texts[placeholder.n] = texts[placeholder.n] or M.snippet_preview(placeholder.text)
		return "${" .. placeholder.n .. ":" .. texts[placeholder.n] .. "}"
	end)
end

--- 展开代码片段
--- 使用 Neovim 内置的代码片段功能展开片段
--- @param snippet string 要展开的代码片段
---
function M.expand(snippet)
	-- 使用公开 API 结束旧会话，避免写入 vim.snippet._session 私有状态。
	if vim.snippet.active() then
		vim.snippet.stop()
	end

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
end

return M

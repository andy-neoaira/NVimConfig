local option = vim.opt

-- 启用自动写入
option.autowrite = true
-- 与系统剪贴板同步
option.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
option.completeopt = "menu,menuone,noselect,popup"
-- 隐藏用于粗体和斜体的 * 标记，但不隐藏带有替换的标记
option.conceallevel = 2
-- 在退出修改过的缓冲区之前确认保存更改
option.confirm = true
-- 启用当前行高亮
option.cursorline = true
-- 使用空格代替制表符
option.expandtab = true
option.fillchars = {
	foldopen = "",
	foldclose = "",
	fold = " ",
	foldsep = " ",
	diff = "╱",
	eob = " ",
}
option.foldlevel = 99
option.formatexpr = "v:lua.require'utils'.format.formatexpr()"
-- tcqj
option.formatoptions = "jcroqlnt"
option.grepformat = "%f:%l:%c:%m"
option.grepprg = "rg --vimgrep"
option.ignorecase = true
option.inccommand = "nosplit"
option.jumpoptions = "view"
option.laststatus = 3
option.linebreak = true
option.list = true
--启用鼠标
option.mouse = "a"
option.number = true
option.pumblend = 10
option.pumheight = 10
option.relativenumber = true

option.ruler = false -- Disable the default ruler
option.scrolloff = 4 -- Lines of context
option.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
option.shiftround = true -- Round indent
option.shiftwidth = 2 -- Size of an indent
option.shortmess:append({ W = true, I = true, c = true, C = true })
option.showmode = false -- Dont show mode since we have a statusline
option.sidescrolloff = 8 -- Columns of context
option.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
option.smartcase = true -- Don't ignore case with capitals
option.smartindent = true -- Insert indents automatically
option.spelllang = { "en" }
option.splitbelow = true -- Put new windows below current
option.splitkeep = "screen"
option.splitright = true -- Put new windows right of current

-- 状态列由 Snacks 在加载后接管；插件未安装时保留内置状态列。
option.tabstop = 2 -- Number of spaces tabs count for
option.termguicolors = true -- True color support
option.timeoutlen = vim.g.vscode and 1000 or 300 -- Lower than default (1000) to quickly trigger which-key
option.undofile = true
option.undolevels = 10000
option.updatetime = 200 -- Save swap file and trigger CursorHold

-- Allow cursor to move where there is no text in visual block mode
option.virtualedit = "block"
-- Command-line completion mode
option.wildmode = "longest:full,full"
-- Minimum window width
option.winminwidth = 5
-- Disable line wrap
option.wrap = false
option.smoothscroll = true
option.foldexpr = "v:lua.require'utils'.ui.foldexpr()"
option.foldmethod = "expr"
option.foldtext = ""

-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0
-- 禁用python文件中 [[ ]] 跳转的映射
vim.g.no_python_maps = 1

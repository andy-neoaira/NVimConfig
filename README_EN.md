# NVimConfig

Personal Neovim configuration using lazy.nvim and Snacks for navigation and search.

See [中文说明](README.md) and the [full review report](OPTIMIZATION_REPORT.md).

## Requirements

Neovim **0.12+**, Git, a Nerd Font, and build tools for Treesitter parsers. Install ripgrep and fd for search. Language servers, formatters, test runners, and debug adapters are separate tools.

Image and Mermaid previews require a compatible terminal and conversion tools. Run `:checkhealth snacks`. Hammerspoon input switching is optional on macOS and is skipped in headless sessions.

## Setup

Back up your existing configuration and data before installing this repository.

1. Start Neovim. Only lazy.nvim bootstraps automatically.
2. Run `:Lazy install` and restart.
3. Run `:ToolsInstall` for configured external tools.
4. Run `:TSInstallConfigured` for parsers.
5. Run `:Copilot auth` if using Copilot completion.

Use `:Lazy update` to update plugins or `:Lazy restore` to restore locked versions. Normal startup does not refresh the Mason registry or download parsers.

CopilotChat retains the custom Moonshot provider and reads `NVIM_AI_API_KEY` from the environment. It does not use Copilot authentication.

## Behavior and customization

Autosave handles modified, named, writable file buffers. Normal-mode edits are debounced by 200ms. Conform formats synchronously on save and falls back to LSP when no external formatter is available.

Set flags before `require("config")` in `init.lua`:

```lua
vim.g.autosave = false
vim.g.autoformat = false
vim.g.input_method = false
vim.g.java_lsp = true -- optional; disabled by default
vim.g.blink_diag = true -- optional event logging
```

Use `vim.b.autosave = false` to disable autosave for one buffer; global autosave disable remains a master switch. Explicit `vim.b.autoformat` values override the global format setting; set to `nil` to inherit.

Java requires nvim-jdtls, jdtls, and JDK 21+. Project settings live in `.nvim/java.json`. Google Java Format supports its standard/AOSP styles. The old configuration misused `length` as line width: `--length` actually specifies a character range and must be paired with `--offset`.

## Keymaps

Leader is Space. Use `<leader>sk` or which-key to inspect all mappings.

| Key | Action |
| --- | --- |
| `<leader>e` / `<C-e>` | Snacks explorer |
| `<leader>ff` / `<leader>sg` | Find files / grep project |
| `<leader>sr` | Search and replace |
| `<leader>cf` | Format manually |
| `<leader>of` / `<leader>oF` | Global / buffer autoformat |
| `<leader>cr` | LSP rename |
| `<leader>om` | Toggle Markdown and inline image preview |
| `<leader>tt` / `<leader>tf` | Run nearest / file tests |
| `<leader>P` | Set project root from the current buffer |
| `<C-a>` | CopilotChat |

Explorer `x` and `m` move files; `y` copies paths and `p` pastes.

## Checks

With plugins, JSON/JSON5 parsers, and StyLua installed:

```sh
sh scripts/check.sh
```

Checks use temporary state/cache/log directories and do not send AI requests. They cover core behavior, async ordering, plugin setup, real format-on-save, and custom query parsing. Terminal graphics and real language/debug/test sessions require separate environment-specific validation.

MIT License.

# NVimConfig

Personal Neovim configuration managed with lazy.nvim, using Snacks for file navigation and search.

[中文说明](README.md)

## Features

- Snacks file explorer, project search, terminal, and Git tools.
- LSP, blink.cmp completion, Conform format-on-save, and autosave.
- neotest, DAP debugging, and Python virtual environment selection.
- Markdown, image, and Mermaid previews, plus Obsidian integration.
- Copilot code completion and CopilotChat through the Moonshot API.

## Requirements

- **Neovim 0.12+**: the baseline for this configuration's Treesitter and LSP setup.
- Git and a Nerd Font; a C toolchain and tree-sitter CLI for parsers, and make for the CopilotChat build.
- ripgrep and fd for search; external formatters and language servers as needed.
- pytest for Python tests and Vitest for JavaScript/TypeScript tests.
- A terminal supporting the Kitty graphics protocol and suitable conversion tools for image and Mermaid previews. Check with `:checkhealth snacks`.
- Optional on macOS: Hammerspoon's `hs` CLI for input source switching. This integration is skipped when the CLI or a UI is unavailable.

## Setup and updates

Back up your existing configuration and data, then place this repository at `~/.config/nvim` (or the Neovim configuration directory under your custom XDG path) and run `nvim`. Keep existing sessions, history, and plugin data.

Only lazy.nvim bootstraps automatically. Install plugins and external tools explicitly:

1. Run `:Lazy install`, then restart Neovim.
2. Run `:ToolsInstall` for the declared language servers, formatters, and debug tools.
3. Run `:TSInstallConfigured` for the configured Treesitter parsers.
4. Run `:Copilot auth` if using Copilot completion.

Normal startup does not refresh the Mason registry or download parsers. Use `:Lazy update` to update plugins or `:Lazy restore` to restore locked versions. Run the checks after updating, especially for changes affecting image compatibility.

CopilotChat uses the Moonshot API and reads its key from `NVIM_AI_API_KEY`; make the variable available before starting Neovim. Chat and Copilot completion use separate authentication. See [copilot-chat.lua](lua/plugins/copilot-chat.lua) for provider and model settings.

## Editing and customization

### Autosave and formatting

Autosave is enabled by default. It saves on leaving Insert mode or losing focus, and waits 200ms after consecutive Normal-mode edits. Only modified, named, writable regular file buffers are saved; failures produce a notification.

Conform formats synchronously on save and falls back to a formatting-capable LSP when external tools are unavailable. JSON uses Prettier first, then jq if Prettier is unavailable.

Set these flags **before** `require("config")` in `init.lua`:

```lua
vim.g.autosave = false       -- Disable global autosave
vim.g.autoformat = false     -- Disable global format-on-save
vim.g.input_method = false   -- Disable input source switching
vim.g.java_lsp = true        -- Optional: enable Java LSP; disabled by default
vim.g.blink_diag = true      -- Optional: log completion events
```

Use `vim.b.autosave = false` or `vim.b.autoformat = false` for one buffer. Global autosave disable is a master switch. Explicit buffer autoformat settings override the global setting; set them to `nil` to inherit. Manual formatting with `<leader>cf` ignores the autoformat toggle.

### Java (optional)

After enabling Java, run `:Lazy install` for nvim-jdtls and `:ToolsInstall` for jdtls. Provide JDK 21+ through `JAVA_HOME` or PATH. Project settings in `.nvim/java.json` can configure the project JDK, Maven settings, offline mode, and Lombok. Java formatting supports Google/AOSP styles:

```json
{ "google_java_format": { "aosp": false } }
```

Set `aosp: true` for AOSP style; this configuration does not offer an arbitrary line-width option. See [nvim-jdtls.lua](lua/plugins/nvim-jdtls.lua) and [conform.lua](lua/plugins/conform.lua) for the full configuration.

### Obsidian (optional)

Vault settings live in [miniobsidian.lua](lua/plugins/miniobsidian.lua). Change `default_vault` to your own Vault name before use; the current value is the author's personal setting.

## Keymaps

Leader is Space. Use `<leader>sk` to inspect all mappings, or press Leader for which-key hints.

| Key | Action |
| --- | --- |
| `<leader>e` / `<C-e>` | Snacks explorer |
| `<leader><space>` / `<leader>ff` | Smart file search / find files |
| `<leader>sg` / `<leader>/` | Search project contents / current buffer lines |
| `<leader>sr` | Search and replace with grug-far |
| `<leader>h/j/k/l` | Move between splits |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<leader>bd` / `<leader>bo` | Close current / other buffers |
| `<leader>cf` | Format manually |
| `<leader>of` / `<leader>oF` | Toggle global / buffer autoformat |
| `<leader>om` | Toggle Markdown, inline image, and Mermaid previews |
| `gd` / `gr` / `gi` / `<leader>cr` | Definition / references / implementation / rename |
| `<leader>ca` / `<leader>cd` | Code actions / line diagnostics |
| `]d` / `[d` | Next / previous diagnostic |
| `<leader>gg` | Lazygit at the project root (requires Lazygit) |
| `<leader>gb` / `<leader>gl` | Git branches / commit history |
| `<leader>tt` / `<leader>tf` / `<leader>td` | Run nearest test / file tests / debug nearest test |
| `<leader>dc` / `<leader>db` | Start or continue debugging / toggle breakpoint |
| `<leader>cv` | Select Python virtual environment |
| `<leader>Ss` / `<leader>SS` | Restore current directory session / select session |
| `<leader>P` | Set working directory to the current file's project root |
| `<C-/>` | Floating terminal |
| `<C-a>` / `<leader>aa` | CopilotChat |
| `<leader>nn` / `<leader>nv` | New Obsidian note / switch Vault |

In the explorer, `y` copies paths and `p` pastes; `x` and `m` open the move action. Deletions use the trash, with protection for the project root.

## Configuration layout

- `init.lua`: configuration entry point.
- `lua/config/`: startup, options, autocommands, and general keymaps.
- `lua/plugins/`: lazy.nvim plugin specifications.
- `lua/utils/lsp_options.lua` and `lsp_keymaps.lua`: language server settings and LSP keymaps.
- `lua/utils/buffer.lua`, `input_method.lua`, `image.lua`, and `python.lua`: autosave, input switching, image compatibility, and interpreter resolution.
- `queries/`: custom JSON/JSON5 context and folding queries.
- `tests/` and [scripts/check.sh](scripts/check.sh): regression checks.
- [AGENTS.md](AGENTS.md): code maintenance and agent collaboration guidelines.

## Checks

Run from the repository root after installing the required plugins and JSON/JSON5 parsers, with `nvim` and `stylua` on PATH:

```sh
sh scripts/check.sh
```

The script checks Lua formatting, core behavior, async callbacks, plugin setup, real format-on-save, and query syntax. State, cache, and logs use temporary directories; tests do not send AI requests. Terminal graphics, real debugging sessions, and individual language projects require separate validation.

These are regression checks for the configuration itself. Run Python/Vitest project tests through neotest or the project's own test commands.

## Troubleshooting

| Problem | Where to check |
| --- | --- |
| Missing plugins or load failures | `:Lazy`; restart after the initial install |
| Unavailable language servers or tools | `:Mason`, `:checkhealth vim.lsp` |
| No formatting on save | `:ConformInfo` and global/buffer `autoformat` settings |
| Missing image or Mermaid previews | `:checkhealth snacks`, terminal protocol support, and conversion tools |
| AI authentication failures | `:Copilot auth` for completion; `NVIM_AI_API_KEY` for chat |

## License

MIT. Thanks to Neovim, LazyVim, and the plugin authors.

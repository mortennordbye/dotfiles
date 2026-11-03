# Neovim config

My [LazyVim](https://github.com/LazyVim/LazyVim) setup, made to feel a bit like VSCode: an
activity bar down the left edge, a Source Control panel in the explorer, side panels for
AI CLIs, and a built-in keybinding cheatsheet. Personal config, shared as is. Take what is
useful.

## Install

Back up anything you already have, then clone into place and start Neovim:

```sh
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/mortennordbye/nvim ~/.config/nvim
nvim
```

The first start installs the plugins, then treesitter parsers and language servers. Give it
a few minutes. Some plugins can end up newer than `lazy-lock.json`; run `:Lazy restore` to
get exactly the pinned versions.

To try it next to your own config without touching it, clone it to `~/.config/nvim-morten`
and run `NVIM_APPNAME=nvim-morten nvim`.

## Requirements

Developed on macOS with Neovim 0.12. It should mostly work on Linux, but that is untested.

- [LazyVim's requirements](https://www.lazyvim.org/#%EF%B8%8F-requirements): git, a C
  compiler, a [Nerd Font](https://www.nerdfonts.com/), and a terminal with true color
- `ripgrep` and `fd`
- Node.js and Python, which several of the language servers Mason installs are built on

### Optional

Everything here is for one feature, and the rest of the config works without it.

| Tool | Used for |
| --- | --- |
| [Claude Code](https://claude.com/claude-code) | Claude panel and Claude Hub |
| GitHub Copilot CLI | Copilot panel and generated commit messages |
| `agy` (Antigravity CLI) | Antigravity panel |
| `gitui` | Git UI from LazyVim's extra |
| Google Chrome | Chromeless preview window on macOS; otherwise your default browser |
| `ruter` CLI | Next departure in the statusline (Oslo public transport) |

Claude Hub lists sessions from `~/.claude/sessions`. Its "needs you" and "your turn" states
also need a Claude Code hook that writes `~/.claude/attention/<session id>`; the format is
described at the top of `lua/config/claude_hub.lua`.

## Things you may want to change

- **Project folders:** the pickers scan `~/Documents/{github,gitlab,local-git}`, set at the
  top of `lua/config/pickers.lua`.
- **Activity bar icons:** `<leader>uX` chooses them and `<leader>uA` hides the bar.
- **Lock Layout:** `<leader>uP` toggles it. See `lua/config/layout.lua`.

## Keybinding cheatsheet

`<leader>h`, or the keyboard icon at the bottom of the activity bar. `s` searches every row.

The content is in `lua/config/cheatsheet_data.lua`. It is written by hand, not generated from
the keymaps, so it drifts silently. When adding, removing or rebinding keys, update the row
in the same commit, and mark keys this config adds with `custom = true` (shown as ★).

Give each row a `kw` with the words you would actually type when looking for it. Search
matches that alongside the keys, description and section, which is how "select multiple"
finds the explorer's `Tab` marking keys even though the row never uses the word "select".

## Markdown preview

`<leader>cp` opens `markdown-preview.nvim` in a chromeless Chrome window. It is tuned in
`lua/plugins/markdown.lua` to behave like the VSCode preview:

- `mkdp_auto_close = 0`. Upstream registers `BufHidden -> preview_close`, so the default
  build kills the browser window the moment you switch buffer.
- `mkdp_combine_preview`. One window, re-pointed at whichever markdown buffer you enter,
  instead of a window per file. When a page is already connected the server only sends it
  `change_bufnr`, so switching files does not raise Chrome over the terminal.
- Extra refresh autocmds. Upstream only refreshes on `CursorHold`/`CursorMoved`, so edits
  that do not move the cursor (undo, `:%s`, a formatter, a write from another process)
  never reach the page. `TextChanged`, `BufWritePost` and friends are wired up too, plus a
  `checktime` so files written outside nvim are reloaded first.
- `<leader>cp` does not use `MarkdownPreviewToggle`. That toggle is tracked per buffer, so
  in combine mode it loses track of itself as soon as the preview follows you to another
  file. `g:mkdp_clients_active` (set by the server when a page connects) is the real state.

There is no file tree inside the preview page, and there is no clean way to add one: the
page is a prebuilt Next.js bundle shipped in `app/out`, and the only injection point the
plugin exposes is `g:mkdp_markdown_css` / `g:mkdp_highlight_css`, which *replace* a
stylesheet rather than adding markup. Patching the minified bundle would be undone by
every plugin update. `<leader>fm` (markdown files picker) does the same job from the nvim
side, since the preview follows the buffer.

Note that `g:mkdp_markdown_css` replaces `/_static/markdown.css` outright, so restyling the
preview means vendoring the whole github-markdown-css file, not overriding a few rules.

# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## Personal notes

### Keybinding cheatsheet

Built in: `<leader>h`, or the keyboard icon at the bottom of the activity bar. The content
is `lua/config/cheatsheet_data.lua`; `lua/config/cheatsheet.lua` shows it as a picker with
each row's section in the preview.

It is written by hand, not generated from the keymaps, so it drifts silently. When adding,
removing or rebinding keys in `lua/config/keymaps.lua` or `lua/plugins/*.lua`, update the
row in `cheatsheet_data.lua` in the same commit, and mark keys this config adds with
`custom = true` (shown as ★).

Give each row a `kw` with the words you would actually type when looking for it. Search
matches that alongside the keys, description and section, which is how "select multiple"
finds the explorer's `Tab` marking keys even though the row never uses the word "select".

It replaced a Raycast HTML cheatsheet (`~/Documents/Scripts/raycast/lazyvim-cheatsheet.*`)
on 2026-09-22; the content was converted from it, nothing was dropped.

The neo-tree → snacks.nvim explorer rewrite is done as of 2026-07-29, and the marking
(multi-select) keys are documented.

### Markdown preview

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

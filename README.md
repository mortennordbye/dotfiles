# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## Personal notes

### Keybinding cheatsheet lives outside this repo

Keybindings are documented by hand in a personal cheatsheet in the Raycast scripts folder:

| File | What it is |
| --- | --- |
| `~/Documents/Scripts/raycast/lazyvim-cheatsheet.html` | The content. Self-contained, searchable, dark/light. **Edit this one.** |
| `~/Documents/Scripts/raycast/lazyvim-cheatsheet.sh` | Raycast script command that opens the HTML in the browser. |

It is **not** generated from this config, so it drifts silently. When adding, removing or
rebinding keys in `lua/config/keymaps.lua` or `lua/plugins/*.lua`, update the cheatsheet in
the same pass.

When adding a row, give it a `data-kw` attribute with the words you would actually type
when looking for it. The filter searches that alongside the visible text and the card
title, which is how "select multiple" finds the explorer's `Tab` marking keys even though
the row never uses the word "select". Rows without `data-kw` are only findable by their
literal wording. Cards need a `data-chip` label; the section chips are generated from it.

The neo-tree → snacks.nvim explorer rewrite is done as of 2026-07-29, and the marking
(multi-select) keys are documented.

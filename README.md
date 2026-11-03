# dotfiles

My configs, one folder per tool. Personal setup, shared as is. Take what is useful.

| Folder | What it is |
| --- | --- |
| [`nvim/`](nvim/README.md) | [LazyVim](https://github.com/LazyVim/LazyVim) made to feel a bit like VSCode: activity bar, Source Control panel, side panels for AI CLIs and a built-in keybinding cheatsheet |
| [`ghostty/`](ghostty/config) | [Ghostty](https://ghostty.org) terminal config, with colors and font icons matched to the Neovim setup |

## Get started

```sh
git clone https://github.com/mortennordbye/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Install anything it lists as missing, then run `nvim`. The first start installs plugins, parsers
and language servers, so give it a few minutes. When it settles, press `Space h` for the
keybinding cheatsheet.

To preview without changing anything, or to link only one config:

```sh
~/dotfiles/install.sh --dry-run
~/dotfiles/install.sh nvim
```

## What the script does

1. Moves anything already at `~/.config/nvim` or `~/.config/ghostty` to a backup, such as
   `~/.config/nvim.bak.20261103-191500`. Nothing is deleted.
2. Creates symlinks from those paths to the folders in this repo.
3. Checks for the tools each config needs, and prints the command to install what is missing.

It installs no packages and never uses `sudo`. It is safe to run again: a config that is
already linked is left alone. It respects `XDG_CONFIG_HOME`, and the repo can live anywhere.

## Update

```sh
git -C ~/dotfiles pull
```

The configs are symlinks, so this is all it takes. Restart Neovim to load the changes, then run
`:Lazy restore` to get the plugin versions pinned in `nvim/lazy-lock.json`.

## Undo

Remove the link and move your backup back. The script printed the backup's name, or use
`ls ~/.config | grep bak`:

```sh
rm ~/.config/nvim
mv ~/.config/nvim.bak.20261103-191500 ~/.config/nvim
```

`rm` on a symlink removes only the link, not this repo. Neovim's plugins and language servers are
stored separately. To remove those too, delete `~/.local/share/nvim`, `~/.local/state/nvim` and
`~/.cache/nvim`. If your old config used them too, it will reinstall what it needs.

## Make it your own

Edits to a linked file change your clone directly, so fork the repo if you want to keep your own
changes. See [`nvim/README.md`](nvim/README.md) for what to change first and what is optional.

Tested on macOS with Neovim 0.12. Linux should mostly work, but it is untested.

# dotfiles

My configs, one folder per tool. Personal setup, shared as is. Take what is useful.

| Folder | What it is |
| --- | --- |
| [`nvim/`](nvim/README.md) | [LazyVim](https://github.com/LazyVim/LazyVim) made to feel a bit like VSCode: activity bar, Source Control panel, side panels for AI CLIs and a built-in keybinding cheatsheet |
| [`ghostty/`](ghostty/config) | [Ghostty](https://ghostty.org) terminal config, with colors and font icons matched to the Neovim setup |

## Install

Clone the repo, then symlink the folders you want. Move any existing config out of the way
first:

```sh
git clone https://github.com/mortennordbye/dotfiles ~/dotfiles

mv ~/.config/nvim ~/.config/nvim.bak
ln -s ~/dotfiles/nvim ~/.config/nvim

mv ~/.config/ghostty ~/.config/ghostty.bak
ln -s ~/dotfiles/ghostty ~/.config/ghostty
```

Each config works without the other. See [`nvim/README.md`](nvim/README.md) for what Neovim
needs. Ghostty needs [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads), and
some of its settings only apply on macOS.

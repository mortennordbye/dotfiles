#!/bin/sh
#
# Links these configs into ~/.config and checks for the tools they need.
#
# It only creates symlinks. Anything already at those paths is moved to a
# timestamped backup, never deleted. It installs no packages and never uses sudo.
# Safe to run again. See --help.

set -eu

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options] [nvim] [ghostty]

Links the named configs into ~/.config. With no names, links both.

Options:
  -n, --dry-run  Show what would change, without changing anything
  -h, --help     Show this help

Examples:
  ./install.sh               Link Neovim and Ghostty
  ./install.sh nvim          Link Neovim only
  ./install.sh --dry-run     Preview first
USAGE
}

DRY_RUN=0
TOOLS=""
for arg in "$@"; do
  case "$arg" in
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    nvim | ghostty) TOOLS="$TOOLS $arg" ;;
    *)
      echo "Unknown option or config: $arg" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
done
[ -n "$TOOLS" ] || TOOLS="nvim ghostty"

REPO=$(cd "$(dirname "$0")" && pwd -P)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
STAMP=$(date +%Y%m%d-%H%M%S)

if [ -t 1 ]; then
  GREEN=$(printf '\033[32m') YELLOW=$(printf '\033[33m')
  BOLD=$(printf '\033[1m') RESET=$(printf '\033[0m')
else
  GREEN="" YELLOW="" BOLD="" RESET=""
fi

ok() { printf '  %sok%s       %s\n' "$GREEN" "$RESET" "$1"; }
todo() { printf '  %s%-8s%s %s\n' "$YELLOW" "$1" "$RESET" "$2"; }
heading() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }

has() { command -v "$1" >/dev/null 2>&1; }

# --- Link -------------------------------------------------------------------

link() {
  src=$REPO/$1
  dest=$CONFIG/$1

  # Already pointing here: nothing to do.
  if [ -L "$dest" ] && [ "$(cd "$dest" 2>/dev/null && pwd -P)" = "$src" ]; then
    ok "$dest already links here"
    return
  fi

  # -L as well as -e: a broken symlink doesn't "exist" but still blocks ln.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup=$dest.bak.$STAMP
    n=1
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup=$dest.bak.$STAMP.$n
      n=$((n + 1))
    done
    if [ "$DRY_RUN" = 1 ]; then
      todo "backup" "would move $dest to $backup"
    else
      mv "$dest" "$backup"
      todo "backup" "moved your old config to $backup"
    fi
  fi

  if [ "$DRY_RUN" = 1 ]; then
    todo "link" "would link $dest to $src"
  else
    mkdir -p "$CONFIG"
    ln -s "$src" "$dest"
    ok "$dest linked to $src"
  fi
}

heading "Linking configs"
for tool in $TOOLS; do
  link "$tool"
done

# --- Check tools ------------------------------------------------------------

BREW="" # Homebrew formulas that are missing
CASKS=""
MISSING=0

missing() {
  todo "missing" "$1"
  MISSING=1
  [ -z "${2:-}" ] || BREW="$BREW $2"
}

nvim_version_ok() {
  version=$(nvim --version | sed -n '1s/^NVIM v\([0-9.]*\).*/\1/p')
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  patch=$(echo "$version" | cut -d. -f3)
  [ "${major:-0}" -gt 0 ] && return 0
  [ "${minor:-0}" -gt 11 ] && return 0
  [ "${minor:-0}" -eq 11 ] && [ "${patch:-0}" -ge 2 ]
}

font_installed() {
  for dir in "$HOME/Library/Fonts" /Library/Fonts "$HOME/.local/share/fonts" "$HOME/.fonts" /usr/share/fonts; do
    if [ -d "$dir" ] && find "$dir" -iname 'JetBrainsMono*Nerd*' 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

check() { # command, what it is for, Homebrew formula
  if has "$1"; then
    ok "$1"
  else
    missing "$1: $2" "$3"
  fi
}

case " $TOOLS " in
  *" nvim "*)
    heading "Neovim needs"
    if has nvim; then
      if nvim_version_ok; then
        ok "nvim $version"
      else
        missing "nvim 0.11.2 or newer (found $version)" neovim
      fi
    else
      missing "nvim 0.11.2 or newer" neovim
    fi
    check git "installs the plugins" git
    if has cc || has gcc || has clang; then
      ok "C compiler"
    else
      missing "C compiler: builds treesitter parsers (macOS: xcode-select --install)"
    fi
    check rg "search" ripgrep
    if has fd || has fdfind; then
      ok "fd"
    else
      missing "fd: file search" fd
    fi
    check node "several language servers run on it" node
    check python3 "several language servers run on it" python
    if font_installed; then
      ok "JetBrainsMono Nerd Font"
    else
      missing "JetBrainsMono Nerd Font: icons (any Nerd Font works for Neovim)"
      CASKS="$CASKS font-jetbrains-mono-nerd-font"
    fi

    heading "Optional, each for one feature"
    for entry in \
      "claude:Claude panel and Claude Hub" \
      "copilot:Copilot panel and generated commit messages" \
      "agy:Antigravity panel" \
      "ruter:next departure in the statusline"; do
      cmd=${entry%%:*}
      if has "$cmd"; then
        ok "$cmd"
      else
        todo "skipped" "$cmd: ${entry#*:}"
      fi
    done
    ;;
esac

case " $TOOLS " in
  *" ghostty "*)
    heading "Ghostty needs"
    if has ghostty || [ -d /Applications/Ghostty.app ]; then
      ok "ghostty"
    else
      missing "ghostty: the terminal itself (https://ghostty.org)"
      CASKS="$CASKS ghostty"
    fi
    if font_installed; then
      ok "JetBrainsMono Nerd Font"
    else
      case " $TOOLS " in
        *" nvim "*) ;; # already reported above
        *)
          missing "JetBrainsMono Nerd Font: the font this config uses"
          CASKS="$CASKS font-jetbrains-mono-nerd-font"
          ;;
      esac
    fi
    ;;
esac

# --- What next --------------------------------------------------------------

if [ "$MISSING" = 1 ]; then
  heading "Install what is missing"
  if has brew; then
    [ -z "$BREW" ] || echo "  brew install$BREW"
    [ -z "$CASKS" ] || echo "  brew install --cask$CASKS"
  else
    echo "  Use your package manager for the tools marked missing above."
  fi
fi

heading "Next"
if [ "$DRY_RUN" = 1 ]; then
  echo "  This was a dry run, nothing changed. Run it again without --dry-run."
else
  case " $TOOLS " in
    *" nvim "*)
      echo "  Run nvim. The first start installs plugins and takes a few minutes."
      echo "  Inside nvim, Space h opens the keybinding cheatsheet."
      ;;
  esac
  case " $TOOLS " in
    *" ghostty "*) echo "  Restart Ghostty to load its config." ;;
  esac
fi

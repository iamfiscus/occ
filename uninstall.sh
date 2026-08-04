#!/bin/sh
# occ uninstaller: removes symlinks, the ~/.zshrc managed block (with .bak),
# and the standalone payload dir — never a live checkout. Tolerant of
# partial installs. Leaves any legacy occ() you migrated out alone.

set -e

BIN_DIR="$HOME/bin"
SHARE_DIR="$HOME/.local/share/occ"
ZFUNCS="$HOME/.local/share/zsh/site-functions"
ZSHRC="$HOME/.zshrc"
MARK_BEGIN="# >>> occ >>>"
MARK_END="# <<< occ <<<"

# resolve what ~/bin/occ points at BEFORE removing it (broken links count)
TARGET=""
[ -L "$BIN_DIR/occ" ] && TARGET=$(readlink "$BIN_DIR/occ" 2>/dev/null || true)

rm -f "$BIN_DIR/occ" "$ZFUNCS/_occ"
echo "==> removed symlinks: $BIN_DIR/occ, $ZFUNCS/_occ"

# payload dir only if this install put it there — never delete a checkout
case "$TARGET" in
  "$SHARE_DIR"/*) rm -rf "$SHARE_DIR"; echo "==> removed payload $SHARE_DIR" ;;
  *) echo "==> kept $SHARE_DIR (not created by this install)" ;;
esac

if [ -f "$ZSHRC" ] && grep -qF "$MARK_BEGIN" "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak.occ-uninstall"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    index($0, b) { skip=1; next }
    index($0, e) && skip { skip=0; next }
    !skip { print }
  ' "$ZSHRC.bak.occ-uninstall" > "$ZSHRC"
  echo "==> removed ~/.zshrc managed block (.zshrc.bak.occ-uninstall saved)"
fi

if [ -L "$HOME/.claude/skills/occ-route" ]; then
  rm -f "$HOME/.claude/skills/occ-route"
  echo "==> removed router skill symlink"
fi

echo "Done. rm -f ~/.zcompdump* && exec zsh to refresh completions."

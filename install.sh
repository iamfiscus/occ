#!/bin/sh
# occ installer: symlinks bin/occ into ~/bin, the completion into a
# site-functions dir, and inserts one managed block into ~/.zshrc
# (PATH + fpath, placed above the oh-my-zsh source line).
#
# Fully self-bootstrapping — works from a checkout or standalone:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamfiscus/occ/main/install.sh)"
#
# Standalone runs download bin/occ + share/occ/models.tsv + completions/_occ
# from main into ~/.local/share/occ and symlink from there.
#
# Idempotent: safe to re-run; re-running IS the update mechanism.
#
# Flags:
#   --migrate   strip the legacy occ() zshrc block (with .bak) instead of
#               refusing. Without it, a zsh function that would SHADOW the
#               installed script causes a loud refusal (silent shadowing is
#               the worst failure mode of this migration).

set -e

BIN_DIR="$HOME/bin"
SHARE_DIR="$HOME/.local/share/occ"
ZFUNCS="$HOME/.local/share/zsh/site-functions"
ZSHRC="$HOME/.zshrc"
RAW_BASE="https://raw.githubusercontent.com/iamfiscus/occ/main"
MARK_BEGIN="# >>> occ >>>"
MARK_END="# <<< occ <<<"
LEGACY_FROM="# occ — launch claude via ollama with a model"
LEGACY_TO="compdef _occ_complete occ"

MIGRATE=0
[ "${1:-}" = "--migrate" ] && MIGRATE=1

# --- Where does this script live? (empty = standalone: curl-pipe) ----------
SRC="${BASH_SOURCE:-$0}"
case "$SRC" in
  ""|bash|sh|-bash|-sh|/dev/stdin|/dev/fd/*) SCRIPT_DIR="" ;;
  *) SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$SRC")" 2>/dev/null && pwd)" || SCRIPT_DIR="" ;;
esac

# --- 0. deps ---------------------------------------------------------------
command -v zsh >/dev/null    || { echo "error: zsh required"; exit 1; }
command -v ollama >/dev/null || { echo "error: ollama not on PATH (brew install ollama)"; exit 1; }
command -v claude >/dev/null || echo "warn: claude CLI not on PATH (occ launches it via ollama)"

# --- 1. legacy zshrc function detection (shadow guard) ---------------------
if [ -f "$ZSHRC" ] && grep -q "^occ()" "$ZSHRC" 2>/dev/null; then
  if [ "$MIGRATE" -eq 1 ]; then
    BAK="$ZSHRC.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$ZSHRC" "$BAK"
    awk -v from="$LEGACY_FROM" -v to="$LEGACY_TO" '
      index($0, from) { skip=1 }
      skip && index($0, to) { skip=0; next }
      !skip { print }
    ' "$BAK" > "$ZSHRC"
    echo "==> migr  legacy occ() block removed ($(basename "$BAK") saved)"
  else
    echo "error: ~/.zshrc still defines an occ() function — it would SHADOW the"
    echo "       installed script (zsh resolves functions before PATH)."
    echo "       Either delete the block by hand, or re-run:  install.sh --migrate"
    exit 1
  fi
fi

# --- 2. lay down the payload ------------------------------------------------
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/occ" ]; then
  SRC_DIR="$SCRIPT_DIR"
  echo "==> src   checkout: $SRC_DIR"
else
  SRC_DIR="$SHARE_DIR"
  echo "==> src   standalone: downloading into $SHARE_DIR"
  rm -rf "$SHARE_DIR"
  mkdir -p "$SHARE_DIR/bin" "$SHARE_DIR/share/occ" "$SHARE_DIR/completions" "$SHARE_DIR/orchestrator"
  for f in bin/occ bin/occ-route share/occ/models.tsv share/occ/occ.conf.example \
           completions/_occ orchestrator/SKILL.md; do
    curl -fsSL "$RAW_BASE/$f" -o "$SHARE_DIR/$f"
  done
  chmod +x "$SHARE_DIR/bin/occ" "$SHARE_DIR/bin/occ-route"
fi

# --- 3. symlinks ------------------------------------------------------------
mkdir -p "$BIN_DIR" "$ZFUNCS"
ln -sf "$SRC_DIR/bin/occ" "$BIN_DIR/occ"
ln -sf "$SRC_DIR/completions/_occ" "$ZFUNCS/_occ"
echo "==> link  $BIN_DIR/occ -> $SRC_DIR/bin/occ"
echo "==> link  $ZFUNCS/_occ -> $SRC_DIR/completions/_occ"

# --- 4. ~/.zshrc managed block (PATH + fpath, above oh-my-zsh) --------------
if [ -f "$ZSHRC" ] && ! grep -qF "$MARK_BEGIN" "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak.occ"
  # build the block in a temp file — BSD awk rejects multi-line -v strings
  BLOCK_FILE=$(mktemp /tmp/occ-block.XXXXXX)
  printf '%s\nexport PATH="$HOME/bin:$PATH"\nfpath=("$HOME/.local/share/zsh/site-functions" $fpath)\n%s\n' \
    "$MARK_BEGIN" "$MARK_END" > "$BLOCK_FILE"
  OUT_FILE=$(mktemp /tmp/occ-zshrc.XXXXXX)
  if grep -q 'source.*oh-my-zsh.sh' "$ZSHRC"; then
    # fpath must land before oh-my-zsh runs compinit
    awk -v bf="$BLOCK_FILE" '
      !done && /source.*oh-my-zsh\.sh/ { system("cat \"" bf "\""); done=1 }
      { print }
    ' "$ZSHRC.bak.occ" > "$OUT_FILE"
  else
    { cat "$BLOCK_FILE"; cat "$ZSHRC.bak.occ"; } > "$OUT_FILE"
  fi
  # never shrink-to-zero on an awk failure: only replace when non-trivial
  if [ "$(wc -l < "$OUT_FILE")" -ge 10 ]; then
    mv "$ZSHRC" "$ZSHRC.pre-occ-block"
    mv "$OUT_FILE" "$ZSHRC"
    echo "==> zshrc managed block inserted (.pre-occ-block saved)"
  else
    echo "error: generated zshrc looks wrong — keeping original"; exit 1
  fi
  rm -f "$BLOCK_FILE"
else
  [ -f "$ZSHRC" ] && echo "==> zshrc managed block already present (skipped)"
fi

# --- 5. example config (never overwrite a user's existing conf) -------------
CONF_DIR="$HOME/.config/occ"
if [ ! -f "$CONF_DIR/occ.conf" ]; then
  mkdir -p "$CONF_DIR"
  cp "$SRC_DIR/share/occ/occ.conf.example" "$CONF_DIR/occ.conf"
  echo "==> conf  $CONF_DIR/occ.conf (from example; all lines commented-off)"
else
  echo "==> conf  $CONF_DIR/occ.conf exists (skipped)"
fi

# --- 6. Claude Code router skill (optional) ---------------------------------
if [ -d "$HOME/.claude/skills" ] && [ ! -e "$HOME/.claude/skills/occ-route" ]; then
  ln -s "$SRC_DIR/orchestrator" "$HOME/.claude/skills/occ-route"
  echo "==> skill ~/.claude/skills/occ-route -> $SRC_DIR/orchestrator"
fi

# --- 7. verify ---------------------------------------------------------------
"$BIN_DIR/occ" --version
"$BIN_DIR/occ" --check >/dev/null && echo "==> check models.tsv OK"

echo
echo "Done. Reload your shell for PATH/completion pickup:"
echo "  rm -f ~/.zcompdump* && exec zsh"

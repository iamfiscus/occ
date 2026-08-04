#!/usr/bin/env zsh
# occ arg-grammar regression tests (needs no ollama daemon: OCC_DRY_RUN=1).
# usage: zsh test/run.zsh       (exit 0 = all pass)
emulate -L zsh
set -u
local OCC="${0:A:h}/../bin/occ"
local fail=0

_t() {  # name expected actual
  if [[ "$3" == "$2" ]]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"
    (( fail++ ))
  fi
}

_t "bare occ"                'model=glm-5.2:cloud args='        "$(OCC_DRY_RUN=1 $OCC)"
_t "dash-first passthrough"  'model=glm-5.2:cloud args=-p hi'   "$(OCC_DRY_RUN=1 $OCC -p hi)"
_t "explicit separator"      'model=glm-5.2:cloud args=-p hi'   "$(OCC_DRY_RUN=1 $OCC -- -p hi)"
_t "code + post-model --"    'model=deepseek-v4-flash:0731-cloud args=--help' \
                             "$(OCC_DRY_RUN=1 $OCC ds -- --help)"
_t "code + claude flag"      'model=qwen3.6:35b-mlx args=-c'    "$(OCC_DRY_RUN=1 $OCC q36 -c)"
_t "alias resolves"          'model=kimi-k3:cloud args='        "$(OCC_DRY_RUN=1 $OCC ui)"
_t "orch dry run"            'orch_model=glm-5.2:cloud tasks=fix the auth module' \
                             "$(OCC_DRY_RUN=1 $OCC orch fix the auth module)"
_t "orch bare (interactive)" 'orch_model=glm-5.2:cloud tasks=<interactive>' \
                             "$(OCC_DRY_RUN=1 OCC_ORCH_MODEL= $OCC orch)"
_t "orch model override"     'orch_model=nemotron-3-ultra:cloud tasks=<interactive>' \
                             "$(OCC_DRY_RUN=1 OCC_ORCH_MODEL=ultra $OCC orch)"
_t "OCC_OTEL env marker"     'model=deepseek-v4-flash:0731-cloud args=-p hi otel=1' \
                             "$(OCC_DRY_RUN=1 OCC_OTEL=1 $OCC ds -p hi)"
_t "OCC_OTEL bare marker"    'model=glm-5.2:cloud args= otel=1' \
                             "$(OCC_DRY_RUN=1 OCC_OTEL=1 $OCC)"
# config file: OCC_OTEL=1 + OCC_MODEL=nano merge, explicit env wins over file
local conf=/tmp/occ-test.$$.conf
cat > "$conf" <<'EOF'
# comment line
OCC_OTEL=1
junk line, skipped
OCC_MODEL=nano
PATH=/do/not/clobber
EOF
_t "occ.conf merges"         'model=nemotron-3-nano:30b-cloud args=-p x otel=1' \
                             "$(OCC_DRY_RUN=1 OCC_CONFIG=$conf $OCC -p x)"
_t "env wins over occ.conf"  'model=glm-5.2:cloud args=-p x' \
                             "$(OCC_DRY_RUN=1 OCC_CONFIG=$conf OCC_MODEL= OCC_OTEL= $OCC -p x)"
rm -f "$conf"
_t "OCC_MODEL override code" 'model=nemotron-3-nano:30b-cloud args=-p x' \
                             "$(OCC_DRY_RUN=1 OCC_MODEL=nano $OCC -p x)"
_t "OCC_MODEL literal tag"   'model=some.tag:v1 args='          "$(OCC_DRY_RUN=1 OCC_MODEL=some.tag:v1 $OCC)"

# exit codes
OCC_DRY_RUN=1 $OCC list >/dev/null 2>&1
_t "reserved subcommand exit 2" "2" "$?"
OCC_DRY_RUN=1 $OCC nosuchmodel >/dev/null 2>&1
_t "unknown model still literal (exit 0)" "0" "$?"
$OCC help >/dev/null 2>&1
_t "occ help exit 0" "0" "$?"
$OCC help 2>/dev/null | grep -q "claude's help"
_t "help documents the split" "0" "$?"
$OCC --check >/dev/null 2>&1
_t "--check exit 0" "0" "$?"
$OCC --version >/dev/null 2>&1
_t "--version exit 0" "0" "$?"
$OCC --emit md 2>/dev/null | grep -q '^| glm |'
_t "--emit md includes glm row" "0" "$?"
$OCC __complete 2>/dev/null | grep -q '^glm:'
_t "__complete includes glm:desc" "0" "$?"

# reserved words stay disjoint from MODEL CODES (router/table invariant)
local codes reserved overlap
codes="$(awk -F'\t' '!/^#/ && NF==11 {print $1; n=split($2,a,","); for (i=1;i<=n;i++) if (a[i]!="-") print a[i]}' \
          "$OCC:h/../share/occ/models.tsv")"
reserved="orch route list audit"
overlap=0
for r in ${(z)reserved}; do
  print -r -- "$codes" | grep -qx -- "$r" && overlap=1
done
_t "code list disjoint from reserved words" "0" "$overlap"

if (( fail > 0 )); then
  printf '\n%d failure(s)\n' "$fail"
  exit 1
fi
printf '\nall tests passed\n'

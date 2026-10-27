# occ — launch Claude Code through ollama, on the right model for the task

`occ` is a thin zsh launcher around `ollama launch claude`. One word picks
the model:

```console
$ occ                    # glm-5.3:cloud — best raw coding (default)
$ occ ds "summarize this diff"   # deepseek-v4.1-flash — fast/cheap routine
$ occ ultra              # nemotron-3-ultra — marathon debugging agents
$ occ ultra -p "trace this flaky test"
$ occ l                  # glm-4.7-flash — local, private / offline
$ occ coder:7b           # any installed local resolves by unambiguous substring
$ occ -p "quick question"        # dash-first: default model, flags to claude
$ occ route "fix layout bug from this screenshot"   # advisory router
```

## Usage

| form | meaning |
|---|---|
| `occ` | interactive, default model |
| `occ MODEL [args]` | TSV code → dynamic local → literal tag; args go to claude |
| `occ -FLAG [args]` | default model; **all** dash-args pass through to claude |
| `occ -- [args]` | explicit separator, default model |
| `occ help / -h` | occ's help (the ONLY tokens occ owns) |
| `occ ds --help` | claude's help (flag lands after the model slot) |
| `occ route <task>` | advisory router — prints a suggestion, never execs |
| `occ orch <tasks>` | route-and-staff orchestrator session (`OCC_ORCH_MODEL` drives it) |
| `occ --check / --emit md / --version` | validator / routing table / version+provenance |

Env: `OCC_MODEL=<code|tag>` (default-model override), `OCC_DRY_RUN=1`
(print the resolved command, don't launch), `OCC_MODELS_TSV=<path>`.

Config: `~/.config/occ/occ.conf` (installed from
`share/occ/occ.conf.example`) holds `KEY=VALUE` lines merged into the
launch env — explicit env vars always win. This is where telemetry and
future wrappers live:

```
OCC_OTEL=1                                # claude telemetry + one OTLP span per launch
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
# future — tapes session capture:
# ANTHROPIC_BASE_URL=http://localhost:8080
```

Tier mixing: `ollama launch` pins every Claude tier (opus, sonnet, haiku,
subagent) to the launched model. Set `OCC_OPUS`, `OCC_SONNET`, `OCC_HAIKU`
or `OCC_SUBAGENT` (a code or a tag, in env or `occ.conf`) to route that tier
elsewhere; occ passes them as `claude --settings '{"env":{...}}'`, which wins
over the env ollama sets:

```
OCC_HAIKU=ds          # background calls on deepseek-v4.1-flash
OCC_SUBAGENT=mm3      # Agent-tool subagents on minimax-m3.1-flash
```

Context window: Claude Code assumes 200K for a model id it doesn't know, and
`ollama launch` only fills in the real window for models it knows. occ sets
`CLAUDE_CODE_MAX_CONTEXT_TOKENS` from the TSV `ctx` column (locals capped at
the 64K occ serves them with) unless you set it yourself.

Every launch gets `OLLAMA_KEEP_ALIVE=-1 OLLAMA_CONTEXT_LENGTH=64000`
(coding-agent floor). Claude always gets `--dangerously-skip-permissions`.

## The model map is data

`share/occ/models.tsv` is the single source of truth for resolution, help,
completion, and the router — quarterly audits edit rows only
(`docs/auditing.md`). `occ --check` validates the file; `zsh test/run.zsh`
regresses the arg grammar without needing the ollama daemon.

Routing policy in one breath: **cloud by default; local only for privacy,
offline, or throwaway tasks**; never <4B models for agentic work; one
18GB+ local at a time. `kimi` is metered billing outside the flat
subscription; `pro` is single-shot-only (worst hallucination profile —
use `ultra` for agents).

## Install

From this checkout (symlinks into it — `git pull` is the update):

```console
$ ./install.sh
```

Standalone (downloads into `~/.local/share/occ`):

```console
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamfiscus/occ/main/install.sh)"
```

Both wire `~/bin` + a completion dir into `~/.zshrc` with one managed
block, and (if present) symlink the `occ-route` Claude Code skill. If your
`~/.zshrc` still carries the legacy `occ()` function, the installer
refuses — it would shadow this one; re-run with `--migrate` to strip it
(with a `.bak`).

Uninstall: `./uninstall.sh` (symlinks, managed block, payload dir — never
a live checkout).

## Router

`occ route [--low-quota] "<task>"` picks a code: deterministic gates first
(privacy/offline → local, low quota → demote, image-file reference →
vision model), then a **local** gemma4 classifier so private task text
never leaves the machine. Advisory output only.

A matching Claude Code skill (`orchestrator/SKILL.md`, installed as
`~/.claude/skills/occ-route`) lets an agent do the same routing with richer
context — same gates, same output contract, same NEVER list.

## Layout

```
bin/occ                  the launcher
bin/occ-route            advisory router (fast gates + local classifier)
share/occ/models.tsv     THE model map (audited quarterly)
completions/_occ         zsh completion (reads the TSV at runtime)
orchestrator/SKILL.md    Claude Code routing skill
docs/auditing.md         quarterly runbook
test/run.zsh             arg-grammar regression suite
```

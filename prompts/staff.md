# Orchestrator prompt — route & staff via occ

Use when planning work that spans model specialties. You (the top-level
agent) are the orchestrator; `occ` is your worker pool.

## 1. Discover the roster — never hardcode models

Run these first, every time:

```zsh
occ --emit md      # live routing table from share/occ/models.tsv
ollama ls          # which locals are actually installed (pull-first vs real)
```

The table is the staffing board. If a code is pull-first and not installed,
it's unavailable unless the user explicitly okays a pull.

## 2. Get the inputs the router cannot see

- quota state (user says low/normal — there is no API; if unsure, say so)
- privacy/offline signals from the task wording
- whether any task references image files (vision gate)

## 3. Fan out assessment

Use the saved workflow:

```
Workflow({scriptPath: "~/dev/occ/workflows/staff.js",
          args: {tasks: [...], quota: "normal", execute: false}})
```

This spawns one routing agent per task (each re-reads the roster live) and
returns `{code, confidence, rationale, brief, warnings}` per task.
Assess-first, staff-second: review the routing plan with the user before
setting execute:true. Never execute a metered code (kimi) or premium quota
code (pro/ultra/q397) without calling out the cost explicitly.

## 4. Staff workers (execute:true)

Each routed task gets a Worker session launched through occ:

```zsh
occ <code> --append-system-prompt-file ~/dev/occ/prompts/worker.md -p "<brief>"
```

Mechanics to respect:

- Everything after the model slot passes through untouched —
  `--append-system-prompt` and `-p` land inside claude, which is why no
  occ changes were needed. Keep the flag AFTER the code.
- Workers are blind: they receive ONLY their brief + repo files. Write
  briefs self-contained; a worker cannot ask questions (they'll state
  assumptions instead — prompt requires it).
- Workers get `--dangerously-skip-permissions` automatically (occ does).
- A worker call is a full claude session — minutes, not seconds. Workflow
  agents launching these need long timeouts.
- Metered codes bill real money ($3/$15 per 1M for kimi) each launch.

## 5. Fan in and report

Collect worker outputs, present the routing table you used (code → tag →
why), worker results, and the warnings. If a worker errored, report the
error verbatim — don't launder it.

## NEVER

- never route <4B models to agentic work; never fp16/bf16 quants
- never auto-pull a missing model (flag it)
- never execute kimi without a dollar-figure confirmation from the user
- never staff premium codes (pro/ultra/q397) under low quota without
  explicit user override
- never override an explicit user-chosen code

# Quarterly model audit — runbook

Cadence: every ~90 days (occ-route warns when models.tsv ages past 90 days).
The map went unnoticed-stale for 5-6 months before the first audit (Aug 2026).

## 1. Research deltas

- Browse https://ollama.com/search?c=cloud for new/retired cloud tags.
- Re-check benchmarks that drive codes: SWE-bench Pro/Verified, Terminal-Bench,
  LiveCodeBench, long-context retrieval (MRCR/RULER/OmniScience). Prefer
  first-party pages for tag/truth; note when numbers are single-source.
- Check billing changes: is a metered model now in the flat sub? New metered
  model? kimi-k3 was metered ($3/$15 per 1M, outside flat sub) at audit time.
- Local inventory: `ollama ls` — stale pulls (>2 months vs library update),
  duplicates, fp16 waste, sub-4B models with occ exposure.

## 2. Edit `share/occ/models.tsv` rows ONLY

- add a model       → one new row (11 tab-separated fields, see header)
- retire a model    → delete the row (commit message carries rationale;
                      git history is the archive)
- re-tier/re-note   → field edits on the existing row
- change default    → move the `default` flag between rows (exactly one
                      default row is enforced by --check)
- bump `# audited:` → today's date

bin/occ changes ONLY on a schema bump: bump `# schema: N` plus the parser
NF check in the same commit.

Hard rules: no tabs or newlines inside any field. .editorconfig pins tabs
for *.tsv — check your editor.

## 3. Validate

    occ --check            # validator: fields, enums, suffixes, dup aliases
    zsh test/run.zsh       # arg-grammar regression suite (no daemon needed)
    occ --emit md          # sanity-eye the routing table the orchestrator reads

## 4. Local hygiene (the August 2026 list, as an example)

    ollama rm glm4:9b-chat-fp16      # fp16 waste: 18GB buys nothing over Q4
    ollama rm <dup>                  # co-loaded 18GB locals = machine swaps
    ollama pull <stale but kept>     # catalog tags move in place

Rules of thumb: never route <4B models to agentic work; one 18GB+ local
loaded at a time (48GB M4 Pro, ~36GB Metal ceiling, ~26GB comfortable);
Q4_K_M / -mlx quants only — fp16/bf16 is pure waste on bandwidth-bound
Apple Silicon.

## 5. Commit + tag

Update docs, commit with rationale, tag when the UX changed.

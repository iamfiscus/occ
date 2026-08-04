export const meta = {
  name: 'staff',
  description: 'Route tasks to occ models by fan-out, then optionally spawn routed workers',
  phases: [
    { title: 'Assess', detail: 'one routing agent per task' },
    { title: 'Staff', detail: 'spawn occ workers in parallel (only with execute)' },
  ],
}

// args: { tasks: ["..."], quota: "normal"|"low", execute: boolean }
// Model roster is fetched live by each assess agent via `occ --emit md` —
// models.tsv is the single source of truth, nothing is hardcoded here.

const ROUTE_SCHEMA = {
  type: 'object',
  properties: {
    task: { type: 'string' },
    code: { type: 'string', description: 'occ model code from the roster' },
    confidence: { type: 'number' },
    rationale: { type: 'string', description: 'one sentence, citing the gate that fired' },
    brief: { type: 'string', description: 'self-contained worker brief: full context, deliverable, output section requirements. The worker sees NOTHING but this text and the repo.' },
    warnings: { type: 'array', items: { type: 'string' }, description: 'metered/quota/pull-first/manual-confirm items; empty if none' },
  },
  required: ['task', 'code', 'confidence', 'rationale', 'brief', 'warnings'],
}

log('Fetching roster + ' + (args?.tasks?.length || 0) + ' task(s)')
const tasks = args?.tasks || []
if (!tasks.length) return { error: 'pass args: { tasks: [..], quota, execute }' }
const quota = args?.quota || 'normal'

phase('Assess')
const routed = (await parallel(tasks.map((t, i) => () =>
  agent(
    `You are one routing assessor. Pick the best occ model code for ONE task.

1. Run \`occ --emit md\` to get the live model roster (do not guess codes).
2. Run \`ollama ls 2>/dev/null | awk 'NR>1 && $3!="-" {print $1}'\` for
   installed locals when a local pick is in play.
3. Route by gates IN ORDER — first that fires wins:
   - PRIVACY/OFFLINE (confidential, client, NDA, offline...) -> first
     installed of: g4c > q35 (q36 only if explicitly complex AND it would be
     the single 18GB+ local); image -> g4; quick -> l. Never auto-pull,
     never <4B, never fp16.
   - VISION (screenshot/mock/OCR/image-file) -> design-critical: kimi ONLY
     with a metering warning added to warnings[]; else vis. Long multimodal
     docs -> content.
   - QUOTA (session quota state is "${quota}") -> if low: mechanical ->
     nano, routine -> ds; hard-block pro/ultra/kimi (flag in warnings[]).
   - TYPE -> frontend non-design-critical: glm; agentic IDE loops: code;
     routine fast: ds; bulk data near 1M ctx: data; marathon debug/plan:
     ultra; single hard backend bug: q397; single-shot max math ONLY: pro
     (add hallucination warning). uncertain -> glm. NEVER default premium.
4. Write the self-contained brief.

Task ${i + 1}: ${t}`,
    { label: `route:${i + 1}`, phase: 'Assess', schema: ROUTE_SCHEMA }
  )
))).filter(Boolean)

log(`routed ${routed.length}/${tasks.length}`)
if (!args?.execute) return { routed, staff: 'not requested (args.execute false)' }

phase('Staff')
const staffed = await parallel(routed.map(r => () =>
  agent(
    `Launch the routed worker for this assignment and return its result.

Run in Bash (capture all output):
  occ ${r.code} --append-system-prompt-file ${'"'}$HOME/dev/occ/prompts/worker.md${'"'} -p "$(cat <<'BRIEF'\n${r.brief}\nBRIEF\n)"

Rules:
- The occ call can take MINUTES — it is a full claude session on another
  model. Give it a long timeout. If it errors, report the error verbatim.
- Return the worker's lead deliverable plus its ASSUMPTIONS/BLOCKERS
  sections. Do not editorialize.
- Warnings from the router that apply: ${JSON.stringify(r.warnings)}`,
    { label: `worker:${r.code}:${r.task.slice(0, 24)}`, phase: 'Staff' }
  ).then(out => ({ task: r.task, code: r.code, out }))
)))

return { routed, staffed }
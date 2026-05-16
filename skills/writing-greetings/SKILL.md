---
name: writing-greetings
description: Reference for writing the `greeting:` field on Claude Code subagent definitions. Use when authoring or editing a subagent definition file (under `.claude/agents/` or `agents/` in a plugin), creating a new subagent, adding a `greeting:` field, or asked how to write or phrase a greeting. Covers the five caller-controlled levers a greeting can address (inputs to pass, methodology to steer, output to request, boundaries, success criteria), anti-patterns, YAML mechanics, and worked examples.
---

# writing-greetings

A guide for authoring the `greeting:` field on a subagent definition. The goal of a greeting is to **teach the main agent what to put in the prompt** so this subagent can do its best work.

## What a greeting is (and isn't)

A greeting surfaces **the levers the caller controls** when invoking your subagent.

| Field | Audience | Purpose | Loaded |
|---|---|---|---|
| `description` | main agent | *Whether* to call this subagent — selection | every session |
| system prompt (body of the agent file) | the subagent itself | *How the subagent behaves* — fixed defaults | when the subagent runs |
| `greeting:` | main agent | *How to write the prompt* once it has decided to call — invocation | on demand, just before delegation |

If you find yourself writing behavior rules (*"you produce severity-tagged reports"*), move them to the system prompt. If you find yourself writing selection cues (*"call me when the user asks about deployment"*), move them to `description`. The greeting is everything left over that helps the *caller* write a better *prompt*.

## The five levers

A greeting addresses up to five categories. Include each one only when it actually applies — empty or boilerplate slots add noise.

### 1. Inputs to pass

Context the subagent can't do its job without: scope, intent, hard requirements, and anything from the caller's session it can't see.

> *"Pass: the file paths in scope, the intent behind the change, and any requirements it must satisfy. Include relevant decisions made earlier in the conversation — I can't see them."*

If the subagent's whole job is to operate on inputs the caller chooses, this lever is rarely optional.

### 2. Methodology to steer

Knobs on *how the work is done* that the caller can set. Distinct from system-prompt defaults: the system prompt fixes behavior; the greeting surfaces the *overridable* parts.

> *"I use websearch — if you want a particular source mix (official docs only? recency cutoff?), say so."*

Include only if (a) the subagent really has the knob, and (b) callers plausibly have a preference. If every caller will use the same setting, leave it as a system-prompt default and don't mention it.

### 3. Output to request

The shape, size, and format of the return.

> *"Tell me the output shape: a list of N URLs, a one-paragraph synthesis, or a full report. Set an explicit word cap — my defaults run long."*

Output is high-leverage because the caller knows what they'll do with the result and the subagent doesn't.

### 4. Boundaries / anti-patterns

What's explicitly out of scope, and what the caller should *not* do when writing the prompt.

> *"Don't paste the whole repo. Don't ask me to also fix what I find — report only. If a path should be ignored, name it."*

### 5. Success criteria

What "done" looks like so the subagent knows when to stop. Often folds into "inputs" as a "requirement," but earns its own slot when the work has a clear terminal state.

> *"Done = the bug is reproduced on current `main`, OR the test that would catch it exists and fails."*

Omit if the work is open-ended (research, brainstorming) — there's no terminal state to define.

## Anti-patterns

- **Restating the system prompt.** *"Tag findings High/Med/Low"* is behavior — it belongs in the body of the agent file, not the greeting.
- **Writing when-to-call hints.** *"Use me when the user mentions deployment"* is `description` territory. A greeting is consulted *after* the call has been decided.
- **Listing every conceivable lever.** A greeting that names methodology knobs no caller will ever care about wastes the budget. Cut anything that isn't real leverage.
- **Generic prompt-writing advice.** *"Write a clear and specific prompt"* adds no value — the caller already knows that. A greeting carries information specific to *this* subagent.
- **Pre-writing the prompt for the caller.** A greeting is *guidance about what to pass*, not a fill-in-the-blank template. Trust the main agent to compose the actual prompt.
- **Boilerplate slots.** If a category doesn't apply, leave it out. Don't write *"Success criteria: N/A"* inside the greeting itself.

## YAML mechanics

Greetings live in the subagent file's YAML frontmatter, alongside `name`, `description`, etc.

```yaml
---
name: my-agent
description: Short description loaded every session.
greeting: |
  Pass: the scope you want me to focus on, and the intent behind it.
  Output: bullets, ≤300 words. Cite primary sources.
  Don't: ask me for clarification — make reasonable assumptions.
---
```

- Use a block scalar (`|`) to preserve newlines. Single-line (`greeting: "..."`) also works, but YAML escape sequences (`\"`, `\n`) are **not** unescaped — keep single-line greetings simple, or switch to `|`.
- An explicit empty value (`greeting: ""` or empty `|` block) is treated the same as a missing key: the lookup falls through to the next source (project, plugin cache, curated built-in, generic fallback). To suppress a curated default, ship a non-empty greeting — even a single space.

## Worked examples

### research-analyst

Does open-ended web research and produces synthesised findings.

- **Inputs to pass** — yes. The research question, plus any decisions or findings from earlier in the session that the subagent can't see.
- **Methodology to steer** — yes. The subagent uses websearch, so source mix and recency cutoff are real overridable defaults.
- **Output to request** — yes. The subagent runs long by default; specifying word cap and shape (URLs vs synthesis vs full report) is high leverage.
- **Boundaries** — light. Worth saying *don't dump raw search results.*
- **Success criteria** — N/A. Open-ended research has no terminal state.

```yaml
greeting: |
  Pass: the research question, plus any decisions or findings from
  earlier in this session — I can't see your conversation history.

  Methodology: say if you have a preference on source mix (official
  docs only? recency cutoff?). My default favours primary sources but
  doesn't filter by date.

  Output: tell me the shape you want — a list of N URLs, a short
  synthesis (≤300 words), or a full report. Set an explicit word cap;
  my defaults run long.

  Don't: ask me to dump raw search results. Synthesise.
```

### code-review

Reviews a set of code changes against the author's stated intent.

- **Inputs to pass** — yes, and these are the load-bearing levers. The diff or files in scope, the intent of the change, and any requirements the change must satisfy. Without these the subagent can't separate intentional changes from bugs.
- **Methodology to steer** — minimal. Reviewing-from-intent is the whole methodology; no knobs worth surfacing.
- **Output to request** — yes. Severity tagging and a max-findings cap keep the report actionable.
- **Boundaries** — yes. Skip style nits, don't apply fixes, don't review unchanged files.
- **Success criteria** — folded into requirements; no separate slot.

```yaml
greeting: |
  Pass: the files or diff in scope, the intent of the change, and any
  requirements it has to satisfy (compatibility, performance, security
  constraints). Without these I can't tell intentional changes from
  bugs.

  Output: severity-tagged findings (High/Med/Low). Cap at the top N
  findings if you only want triage, otherwise say "all findings."

  Don't: ask me to also fix what I find — report only. Skip style
  nits unless you specifically ask for them. Don't pass code I didn't
  change unless it's directly relevant.
```

### db-migration

Authors database migrations for production tables. Highly safety-sensitive.

- **Inputs to pass** — yes. Table size, write volume, online-vs-offline preference, and whether a backfill default is acceptable. Required for safety.
- **Methodology to steer** — limited. The subagent's safety rules are fixed in the system prompt; the caller mostly sets parameters, not method.
- **Output to request** — yes. Whether to include a rollback (`down`), example backfill SQL, or just the forward migration.
- **Boundaries** — yes. Don't apply the migration, don't invent constraints, don't assume dev/prod schemas match.
- **Success criteria** — yes. The migration is "done" when it satisfies the caller's stated locking, downtime, and rollback requirements.

```yaml
greeting: |
  Pass: the table name and approximate row count, write volume
  (idle / steady / hot), whether this is an online migration (no
  exclusive locks tolerated) or offline. State whether a NOT NULL
  with a backfill default is acceptable, or whether the column must
  stay nullable.

  Output: the forward migration, and the matching `down` migration
  unless you explicitly say "forward only." If a backfill is needed,
  include the backfill SQL separately so I can stage it.

  Don't: apply the migration yourself. Don't invent constraints I
  wasn't asked to add. Don't assume dev and prod schemas match —
  describe any drift.

  Done when: the migration satisfies the locking, downtime, and
  rollback requirements you stated.
```

## Author checklist

Before shipping a greeting, ask:

- For each of the five levers — does it apply to *this* subagent? If not, leave it out.
- Does any line restate the subagent's system prompt? Cut it.
- Does any line tell the main agent *when* to call this subagent? Move it to `description`.
- Is any line generic prompt-writing advice ("be clear", "be specific")? Cut it.
- Could a thoughtful caller infer the line from `description` alone? If yes, it's not earning its place.
- Length: would the greeting still be useful at half the size? If yes, shorten it.

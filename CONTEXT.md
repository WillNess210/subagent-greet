# subagent-greet

A Claude Code plugin that adds a `greeting:` field to subagent definitions, giving the main agent on-demand guidance on how to invoke each subagent well.

## Language

**Greeting**:
A field on a subagent's definition that tells the main agent how to invoke this subagent for the best result — surfacing the levers the caller controls. Fetched on demand, just before delegation.
_Avoid_: calling guidance (prose only), invocation instructions, prompt template

**Subagent**:
An agent the main agent delegates a task to via the `Agent` tool; receives exactly two channels of context — its own system prompt (static) and the prompt the main agent passes (per call).
_Avoid_: sub-agent, child agent, worker

**Main agent**:
The orchestrating agent that decides to delegate and writes the prompt passed to a subagent.
_Avoid_: parent agent, caller (caller is fine in prose, not as the canonical term), orchestrator

**Description** (of a subagent):
The always-loaded field that tells the main agent *when* to call this subagent — selection, not invocation.

**System prompt** (of a subagent):
The static instructions that fix how the subagent behaves; a greeting may name which of these defaults the main agent can override, but never restates them.

## Greeting elements

A greeting addresses up to five categories of caller-controlled lever, each only when it actually applies to this subagent:

1. **Inputs to pass** — context the subagent can't do its job without: scope, intent, hard requirements, and anything from the caller's session it can't see.
2. **Methodology to steer** — knobs on *how* the work is done that the caller can set (e.g. "if you care which sources websearch favors, say so"). Include only if the subagent has such a knob and the caller plausibly has a preference.
3. **Output to request** — the shape, size, and format of the return (e.g. "a list of N URLs, not a report"; "≤300 words"; "a unified diff, not prose").
4. **Boundaries / anti-patterns** — what's explicitly out of scope, and what the caller should *not* do (e.g. "don't paste the whole repo"; "make assumptions instead of asking").
5. **Success criteria** — what "done" looks like so the subagent knows when to stop (e.g. "the bug is reproduced"; "the migration is reversible").

## Relationships

- A **subagent** has one **description** (always loaded), one **system prompt** (static), and optionally one **greeting** (loaded on demand).
- The **description** governs *whether* the **main agent** calls the **subagent**; the **greeting** governs *how* it writes the prompt once it has decided to.
- A **greeting** is authored against the **subagent**'s **system prompt** — it tells the **main agent** what that system prompt needs fed to it, and which of its defaults are overridable.

## Example dialogue

> **Author:** "Should my code-review subagent's greeting say 'tag findings High/Med/Low'?"
> **Reviewer:** "No — that's behavior, it belongs in the **system prompt**. The **greeting** tells the **main agent** what to *pass*: 'give me the diff in scope, the intent of the change, and any requirements it must satisfy.'"
> **Author:** "What about 'prefer official docs'?"
> **Reviewer:** "Only if the **subagent** does open-ended research *and* the **main agent** realistically has a preference. For a code reviewer, no. For a research-analyst, yes — that's a methodology lever worth surfacing."

## Flagged ambiguities

- "Greeting = what to pass" — too narrow. Resolved: a greeting covers five lever categories (inputs, methodology, output, boundaries, success criteria), not just inputs.
- "Put how-to-call guidance in the description" — conflates two fields. Resolved: **description** = *when* (selection); **greeting** = *how* (invocation). Distinct.

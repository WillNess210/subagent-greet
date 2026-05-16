---
name: subagent-greet
description: Loads per-subagent calling guidance before invoking the Agent tool. Activate this skill BEFORE every Agent (subagent) invocation. It runs a script that returns a curated greeting — prompt-writing tips, gotchas, examples — for the target subagent. Use this whenever you are about to delegate to a subagent.
---

# subagent-greet

Before invoking any subagent via the `Agent` tool, run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/subagent-greet.sh <subagent-id>
```

`<subagent-id>` is the exact `subagent_type` you intend to pass to the `Agent` tool (e.g., `Explore`, `general-purpose`, `research-analyst`, `vercel:ai-architect`).

The script writes guidance to stdout. Read it, then write the `Agent` tool's `prompt` informed by that guidance.

## Rules

- Run this **before** the `Agent` tool call. **Never in parallel** — the greeting must influence how you write the prompt, so it has to land in context first.
- Run **once per delegation**. No need to re-run for follow-up `SendMessage` calls to the same subagent.
- Apply the guidance: required inputs, common pitfalls, length caps, output format expectations.
- If the output is the generic fallback ("Call the X subagent with the best possible prompt..."), proceed with your best judgment — no curated greeting exists for that id yet.

## Why

The subagent `description` field is loaded into the main agent's context for every session. It must stay short. But the *best* prompt-writing guidance for a given subagent is often hundreds of tokens — gotchas, examples, required fields, output shape. That guidance is wasted context when the subagent isn't being called.

`greeting:` is a YAML frontmatter field on subagent definition files (`~/.claude/agents/*.md`, `<project>/.claude/agents/*.md`). It loads only when this skill fetches it, immediately before invocation — high-leverage context, on demand.

> To author a greeting for one of your own subagents, see the `writing-greetings` skill — the framework, anti-patterns, and worked examples live there.

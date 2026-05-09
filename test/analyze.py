#!/usr/bin/env python3
"""Analyze a Claude Code stream-json transcript for subagent-greet behavior.

Reads NDJSON from stdin and asserts, in order:
  1. SessionStart hook injected the plugin's rule into context.
  2. The subagent-greet skill was activated.
  3. The subagent-greet.sh script was invoked via Bash before the Agent call.
  4. The Agent tool was invoked with subagent_type "Explore".

Exit 0 on full pass, 1 on any failure.
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from typing import Optional


HOOK_RULE_MARKER = "Subagent invocation rule"
GREET_SCRIPT_RE = re.compile(r"subagent-greet\.sh\b")


@dataclass
class Hit:
    event_index: int
    location: str
    snippet: str = ""


@dataclass
class Findings:
    hook: Optional[Hit] = None
    skill: Optional[Hit] = None
    greet: Optional[Hit] = None
    explore: Optional[Hit] = None
    raw_events: int = 0
    parse_errors: list[str] = field(default_factory=list)


def walk_strings(obj, path="$"):
    if isinstance(obj, str):
        yield path, obj
    elif isinstance(obj, dict):
        for k, v in obj.items():
            yield from walk_strings(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_strings(v, f"{path}[{i}]")


def walk_objects(obj, path="$"):
    if isinstance(obj, dict):
        yield path, obj
        for k, v in obj.items():
            yield from walk_objects(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_objects(v, f"{path}[{i}]")


def is_agent_explore_tool_use(node) -> bool:
    if not isinstance(node, dict):
        return False
    if node.get("type") != "tool_use" or node.get("name") != "Agent":
        return False
    inp = node.get("input") or {}
    return isinstance(inp, dict) and inp.get("subagent_type") == "Explore"


def is_subagent_greet_skill(node) -> bool:
    if not isinstance(node, dict):
        return False
    if node.get("type") != "tool_use" or node.get("name") != "Skill":
        return False
    inp = node.get("input") or {}
    skill = inp.get("skill", "") if isinstance(inp, dict) else ""
    return "subagent-greet" in skill


def is_greet_script_bash(node) -> bool:
    if not isinstance(node, dict):
        return False
    if node.get("type") != "tool_use" or node.get("name") != "Bash":
        return False
    inp = node.get("input") or {}
    cmd = inp.get("command", "") if isinstance(inp, dict) else ""
    return "subagent-greet.sh" in cmd


def short(s: str, n: int = 140) -> str:
    s = " ".join(s.split())
    return s if len(s) <= n else s[: n - 1] + "…"


def analyze(stream: str) -> Findings:
    findings = Findings()
    for i, line in enumerate(stream.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as e:
            findings.parse_errors.append(f"line {i}: {e}")
            continue
        findings.raw_events += 1

        for path, s in walk_strings(event):
            if findings.hook is None and HOOK_RULE_MARKER in s:
                findings.hook = Hit(i, path, short(s))
        for path, node in walk_objects(event):
            if findings.skill is None and is_subagent_greet_skill(node):
                findings.skill = Hit(i, path, f"Skill(skill={node['input'].get('skill')})")
            if findings.greet is None and is_greet_script_bash(node):
                cmd = node["input"].get("command", "")
                findings.greet = Hit(i, path, f"Bash({short(cmd)})")
            if findings.explore is None and is_agent_explore_tool_use(node):
                findings.explore = Hit(i, path, "Agent(subagent_type=Explore)")
    return findings


def main() -> int:
    data = sys.stdin.read()
    if not data.strip():
        print("FAIL: empty transcript", file=sys.stderr)
        return 1

    f = analyze(data)

    print(f"events parsed: {f.raw_events}")
    if f.parse_errors:
        print(f"parse errors:  {len(f.parse_errors)} (first: {f.parse_errors[0]})")

    checks = [
        ("SessionStart hook injected rule", f.hook),
        ("subagent-greet skill activated",  f.skill),
        ("subagent-greet.sh invoked",       f.greet),
        ('Agent tool called with subagent_type "Explore"', f.explore),
    ]

    failed = 0
    for name, hit in checks:
        if hit:
            print(f"[PASS] {name}  (event #{hit.event_index} {hit.location})")
            if hit.snippet:
                print(f"       → {hit.snippet}")
        else:
            print(f"[FAIL] {name}")
            failed += 1

    order_ok = True
    if f.hook and f.skill and f.hook.event_index > f.skill.event_index:
        print("[FAIL] hook fired AFTER skill activation"); order_ok = False
    if f.skill and f.explore and f.skill.event_index > f.explore.event_index:
        print("[FAIL] skill activated AFTER Agent call"); order_ok = False
    if f.greet and f.explore and f.greet.event_index > f.explore.event_index:
        print("[FAIL] greet script ran AFTER Agent call (must run before)"); order_ok = False
    if order_ok and all(h for _, h in checks):
        print("[PASS] ordering: hook → skill → greet → explore")
    elif not order_ok:
        failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

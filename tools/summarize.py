#!/usr/bin/env python3
"""Summarize results/arena.jsonl by tag: Glory, win, timeout, XP, end time, class mix."""
import collections
import json
import statistics
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "results/arena.jsonl"
tags = sys.argv[2:]
rows = collections.defaultdict(list)
for line in open(path):
    r = json.loads(line)
    if "error" in r:
        continue
    if tags and r["tag"] not in tags:
        continue
    rows[r["tag"]].append(r)

print(f"{'tag':28} {'n':>4} {'glory':>12} {'win':>5} {'loss':>5} {'tmo':>5} {'xp':>6} {'winmin':>6}  classes")
for tag, rs in rows.items():
    n = len(rs)
    g = [r["score"] for r in rs]
    se = statistics.pstdev(g) / max(1, n - 1) ** 0.5
    win = sum(r["won"] for r in rs) / n
    tmo = sum(r["timeout"] for r in rs) / n
    loss = 1 - win - tmo
    wm = [r["ticks"] / 1440 for r in rs if r["won"]]
    cls = collections.Counter(r.get("cls", -1) for r in rs)
    print(f"{tag:28} {n:4d} {statistics.mean(g):7.1f}±{se:4.1f} {win:5.2f} {loss:5.2f} {tmo:5.2f} "
          f"{statistics.mean(r['xp'] for r in rs):6.0f} {statistics.mean(wm) if wm else 0:6.1f}  {dict(cls)}")

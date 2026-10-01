#!/usr/bin/env python3
"""Local GOTA A/B arena.

Runs full Competition-variant episodes of the official game image with one
candidate policy in a rotating seat and a field policy (default: the league
baseline base.bas) in the other nine seats. Reports the candidate seat's
Emmett's Glory score, win/loss/timeout, XP and match length.

Usage:
  python3 tools/arena.py CANDIDATE.bas -n 40 [--field reference/base.bas]
         [--seed 5000] [-j 3] [--tag name] [--mix reference/rusher.bas]

Requires: docker running, uv, and a downloaded Coworld
(uv run coworld download cow_27bb6139-9311-4b52-b178-c267b7865167) inside
COWORLD_DIR (default: tools/.cw).
"""
import argparse
import concurrent.futures as cf
import hashlib
import secrets
import time
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path

COW = "cow_27bb6139-9311-4b52-b178-c267b7865167"
ROOT = Path(__file__).resolve().parent.parent
CW_DIR = Path(os.environ.get("COWORLD_DIR", ROOT / "tools" / ".cw"))
WORK = Path(os.environ.get("ARENA_WORK", tempfile.gettempdir())) / "gota-arena"


def manifest() -> dict:
    return json.loads((CW_DIR / "coworld" / COW / "coworld_manifest.json").read_text())


def run_game(files, seed, out):
    """Stage a game-hosted episode exactly like `coworld run-episode` and run the
    official game image directly (the CLI serializes parallel runs)."""
    m = manifest()
    image = m["game"]["runnable"]["image"]
    cfg = dict(next(v["game_config"] for v in m["variants"] if v["id"] == "competition"))
    cfg["seed"] = seed
    cfg["tokens"] = [secrets.token_urlsafe(16) for _ in range(10)]
    (out / "logs").mkdir(parents=True, exist_ok=True)
    (out / "config.json").write_text(json.dumps(cfg))
    seats = []
    for slot, f in enumerate(files):
        data = Path(f).read_bytes()
        d = out / "players" / str(slot)
        d.mkdir(parents=True, exist_ok=True)
        (d / "file").write_bytes(data)
        seats.append({"slot": slot, "file_uri": f"file:///coworld/players/{slot}/file",
                      "content_hash": "sha256:" + hashlib.sha256(data).hexdigest(), "size_bytes": len(data),
                      "log_uri": f"file:///coworld/logs/policy_agent_{slot}.log",
                      "artifact_uri": f"file:///coworld/policy_artifact_{slot}.zip"})
    (out / "player_seats.json").write_text(json.dumps(
        {"schema": "coworld-player-seats/1", "seats": seats,
         "player_status_uri": "file:///coworld/player_status.json"}))
    name = "arena-" + secrets.token_hex(6)
    env = {"COGAME_HOST": "0.0.0.0", "COGAME_PORT": "8080",
           "COGAME_CONFIG_URI": "file:///coworld/config.json",
           "COGAME_RESULTS_URI": "file:///coworld/results.json",
           "COGAME_SAVE_REPLAY_URI": "file:///coworld/replay",
           "COGAME_PLAYER_FAILURE_URI": "file:///coworld/player_failure.json",
           "COGAME_PLAYER_SEATS_URI": "file:///coworld/player_seats.json"}
    cmd = ["docker", "run", "--rm", "--name", name]
    for k, v in env.items():
        cmd += ["-e", f"{k}={v}"]
    cmd += ["-v", f"{out}:/coworld:rw", image]
    results = out / "results.json"
    with open(out / "logs" / "game.stdout.log", "w") as so, open(out / "logs" / "game.stderr.log", "w") as se:
        proc = subprocess.Popen(cmd, stdout=so, stderr=se)
        t0 = time.time()
        while time.time() - t0 < 900:
            if results.exists() and results.stat().st_size > 0:
                time.sleep(1)
                break
            if proc.poll() is not None:
                break
            time.sleep(1)
        subprocess.run(["docker", "rm", "-f", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        proc.wait()
    res = json.loads(results.read_text())
    stdout = (out / "logs" / "game.stdout.log").read_text()
    return res, stdout


def one(args):
    idx, cand, field_files, seat, seed, tag = args
    files = list(field_files)
    files[seat] = cand
    out = WORK / "runs" / tag / f"g{idx:04d}_s{seed}_seat{seat}"
    if out.exists():
        shutil.rmtree(out)
    try:
        res, stdout = run_game(files, seed, out)
    except Exception as exc:  # noqa: BLE001
        return {"idx": idx, "seed": seed, "seat": seat, "error": str(exc)}
    team = 0 if seat < 5 else 1
    outcome = res["outcome"]
    won = (outcome == "RedTeam" and team == 0) or (outcome == "BlueTeam" and team == 1)
    timeout = outcome not in ("RedTeam", "BlueTeam")
    log = (out / "logs" / f"policy_agent_{seat}.log").read_text(errors="replace")
    m = re.search(r"CLASS (\-?\d+)", log)
    rec = {
        "idx": idx, "seed": seed, "seat": seat, "team": team,
        "score": res["scores"][seat], "xp": res["total_xp"][seat],
        "team_scores": res["scores"], "ticks": res["ticks"], "outcome": outcome,
        "won": won, "timeout": timeout, "cls": int(m.group(1)) if m else -1,
        "towers": re.search(r"towers: (.*)", stdout).group(1) if "towers:" in stdout else "",
        "disabled": "disabled" in log.lower() or "error" in log.lower(),
    }
    if not os.environ.get("ARENA_KEEP"):
        shutil.rmtree(out, ignore_errors=True)
    return rec


def summarize(recs, label):
    ok = [r for r in recs if "error" not in r]
    n = len(ok)
    if not n:
        print(label, "no results")
        return
    scores = [r["score"] for r in ok]
    wins = sum(r["won"] for r in ok)
    tos = sum(r["timeout"] for r in ok)
    mean = statistics.mean(scores)
    se = statistics.pstdev(scores) / max(1, n - 1) ** 0.5
    win_ticks = [r["ticks"] for r in ok if not r["timeout"]]
    print(f"{label}: n={n} glory={mean:.1f}±{se:.1f} win={wins/n:.2f} timeout={tos/n:.2f} "
          f"xp={statistics.mean(r['xp'] for r in ok):.0f} "
          f"end_min={statistics.mean(win_ticks)/1440 if win_ticks else 0:.1f} "
          f"errors={len(recs)-n} vmfail={sum(r['disabled'] for r in ok)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("candidate")
    ap.add_argument("-n", type=int, default=20)
    ap.add_argument("--field", default=str(ROOT / "reference" / "base.bas"))
    ap.add_argument("--mix", action="append", default=[], help="extra field policies, cycled into seats")
    ap.add_argument("--seed", type=int, default=5000)
    ap.add_argument("-j", type=int, default=3)
    ap.add_argument("--tag", default=None)
    ap.add_argument("--out", default=None, help="append JSON lines here")
    ap.add_argument("--seats", default="0,1,2,3,4,5,6,7,8,9")
    a = ap.parse_args()
    cand = Path(a.candidate).resolve()
    tag = a.tag or cand.stem
    seats = [int(s) for s in a.seats.split(",")]
    pool = [Path(a.field).resolve()] + [Path(p).resolve() for p in a.mix]
    jobs = []
    for i in range(a.n):
        seat = seats[i % len(seats)]
        seed = a.seed + i // len(seats)
        field = [pool[(k + i) % len(pool)] for k in range(10)]
        jobs.append((i, cand, field, seat, seed, tag))
    recs = []
    with cf.ThreadPoolExecutor(a.j) as ex:
        for rec in ex.map(one, jobs):
            recs.append(rec)
            if a.out:
                with open(a.out, "a") as f:
                    f.write(json.dumps({"tag": tag, **rec}) + "\n")
            if "error" in rec:
                print("ERR", rec, file=sys.stderr)
    summarize(recs, tag)


if __name__ == "__main__":
    main()

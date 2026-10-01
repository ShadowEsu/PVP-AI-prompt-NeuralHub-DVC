# AGENTS.md

Guidance for coding agents working on this GOTA policy.

## Read first

1. League participation guide: https://softmax.com/api/observatory/v2/participate?league_id=league_080e6abb-597b-45e3-ab21-63321905fdd6
2. Game README (rules, scoring, BASIC API): `reference/GOTA_README.md`. Refresh it from `game.docs.readme` in a newly downloaded manifest when the coworld version changes.
3. Engine source that matches the live build: https://github.com/Metta-AI/polyworld/tree/main/examples/gods_of_the_arena (`sim.nim`, `content.nim`, `bots.nim`). The community wiki is useful but was out of date on scoring, items and limits when we checked.
4. `STRATEGY.md` for the current model of the game, `CHANGELOG.md` for what was tried.

## Working agreement

1. Never overwrite the best known policy. New ideas go in `policies/hero_vN.bas`. Only copy to `Hero.bas` after an A/B test shows a real gain.
2. Change one subsystem at a time. Test with `tools/arena.py` on at least 30 games per variant, same seeds, and compare with `tools/summarize.py`.
3. Record every revision in `CHANGELOG.md` (hypothesis, change, result, keep or revert) and numbers in `MATCH_RESULTS.md`.
4. Use only host functions registered in `bots.nim`. If something is unknown, mark it unknown.
5. Keep the VM inside its limits (legacy API: 256 globals, 32 arrays, 4,096 array cells, 100,000 instructions per decision). A runtime error disables the hero for the rest of the match.
6. Every upload needs `--title` (max 50 chars) and `--description` (max 600 chars).
7. Do not submit to the league or exploit the platform. Ask the human before league submission.

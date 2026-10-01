# Policy Changelog

Each revision lists the hypothesis, what changed, the test, and the keep or revert decision. Numbers live in `MATCH_RESULTS.md`.

## v1: official starter (baseline)

File: `policies/hero_v1.bas`. Softmax IDE revision 1, identical in behavior to the official `base.bas` (legacy flat API instead of structured records).

Result: 10 starter heroes time out 24 of 24 local games. Glory 0.

## v2: lane pusher

File: `policies/hero_v2.bas`.

**Hypothesis.** Starter teams never finish a lane because towers get no target priority and heroes never wait for creep cover. One hero that pushes a lane under creep cover and takes tower last hits can turn timeouts into wins and earn far more XP.

**Changes.**

1. Draft by preference list (Berserker first) instead of first free role.
2. Lane plan: tracks the 9 enemy lane towers, 2 guards and the god by position, marks them dead when we stand next to the spot and cannot see them.
3. Tower rule: hit a tower only with 2+ of our creeps in its range and the tower not targeting us, or to finish it. Otherwise hold 12 tiles back.
4. New target scores: god +3000, safe tower +700 (+500 near death), barracks +350, killable heroes +350 to +650.
5. Ultimates only on heroes and structures. Mana reserved for the ultimate when enemy heroes are near.
6. Recover in lane with potions instead of walking home. Go home only without potions or under 15% HP.
7. Item build: potions and a portal first, then Battle Axe, Rune Crossbow, Knight Armor, Sunsteel (mages: Spellbook, mana potions).
8. Buyback only with more than 12 s of respawn left. Decision every 3 ticks instead of 6.

**Bugs found while testing (fixed inside v2).**

1. Holding outside tower range used attack move, which auto targets the tower and walked the hero into tower fire at level 1. Now it walks.
2. Neutral camps next to lane routes (for example the high camp near the east lane) attacked the hero with no response, draining it to 10% HP repeatedly. Now it fights back above 50% HP and walks clear below.

**Result.** Testing in progress (lane 0, 1, 2 comparison).

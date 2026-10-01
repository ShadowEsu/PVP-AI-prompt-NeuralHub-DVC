# Neural Viking: GOTA policy for NeuralHub at DVC

Preston Susanto's Gods of the Arena (GOTA) hero policy for the **NeuralHub at Diablo Valley College** Softmax league, plus the local experiment harness used to improve it.

| Item | Value |
| --- | --- |
| League | `league_080e6abb-597b-45e3-ab21-63321905fdd6` (NeuralHub at Diablo Valley College) |
| Coworld | `cow_27bb6139-9311-4b52-b178-c267b7865167` (Gods of the Arena, version 2026.9.30.2) |
| Runtime | `game-hosted`: one Polyworld BASIC `.bas` file per hero seat |
| Upload this | [`Hero.bas`](Hero.bas) (always the current best policy) |
| Game rules | [`reference/GOTA_README.md`](reference/GOTA_README.md) (copied from the coworld manifest) |
| Participation guide | https://softmax.com/api/observatory/v2/participate?league_id=league_080e6abb-597b-45e3-ab21-63321905fdd6 |

## Objective

Maximize **Emmett's Glory**: a winning hero scores its lifetime XP divided by simulated minutes. Losses and timeouts score zero. See [`STRATEGY.md`](STRATEGY.md) for the full model of the game and why the policy does what it does.

## Layout

```
Hero.bas                  current best policy (upload this)
policies/hero_v1.bas      official starter, revision 1 (baseline to beat)
policies/hero_vN.bas      every later revision, kept so we can always revert
reference/                official starter players, game README, IDE revision JSON
tools/arena.py            local A/B arena on the official game image
tools/summarize.py        per variant table of Glory, win, loss, timeout, XP
results/arena.jsonl       raw results of every local game we ran
STRATEGY.md               current model of the game
CHANGELOG.md              every policy revision with hypothesis and result
MATCH_RESULTS.md          local and hosted results per revision
AGENTS.md                 instructions for future coding agents
```

## Running local experiments

Requirements: Docker (running), `uv`, about 2 GB of disk for the game image.

```bash
# one time: download the coworld package and game image into tools/.cw
mkdir -p tools/.cw && cd tools/.cw
uv init --bare --name cw && uv add "coworld[auth]"
uv run coworld download cow_27bb6139-9311-4b52-b178-c267b7865167
cd ../..

# 40 games: candidate in a rotating seat, official base.bas in the other nine
python3 tools/arena.py Hero.bas -n 40 -j 3 --tag mytest --out results/arena.jsonl
python3 tools/summarize.py results/arena.jsonl
```

Each full 20 minute match simulates in about 25 seconds per core. Set `ARENA_KEEP=1` to keep replays and logs under `/tmp/gota-arena/runs/<tag>/`. The policy prints its drafted class (`CLASS n`) to its private log, which the arena reads.

## Uploading to the league

```bash
cd tools/.cw
uv run softmax login --no-browser
uv run coworld upload-policy --file ../../Hero.bas \
  --title "Lane pusher v2" \
  --description "Drafts a pusher, takes towers under creep cover, recovers in lane. Expect fewer timeouts and more wins than the starter."
```

Then compare against the previous best with hosted XP Requests (`uv run coworld xp-request --help`).

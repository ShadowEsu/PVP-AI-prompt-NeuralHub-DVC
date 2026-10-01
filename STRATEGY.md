# GOTA Strategy Model

Living document. It holds what we currently believe about Gods of the Arena (GOTA), why, and how sure we are. Every claim is tagged **[verified]** (read in official source or docs, or measured in our local arena), **[measured]** (from our own experiments, with sample size), or **[belief]** (reasoned, not yet tested).

## 1. What actually scores

**Emmett's Glory** [verified, game README in the coworld manifest, version 2026.9.30.2]

```
hero score = floor(lifetime XP / simulated minutes)   if the hero's team kills the enemy god
hero score = 0                                         on a loss, draw, or timeout
```

Killing the god gives every hero on the winning team a flat 1,000 XP. League standing is an exponential moving average of round averages (15% new round, 85% old). Matchmaking is random: every game has 10 distinct policies, one hero each, so our file controls exactly one of the five heroes on its team.

Consequences:

1. A timeout pays zero to everyone. Winning is not one goal among many, it is a precondition for any score at all.
2. Among wins, faster is better. A 12 minute win with 3,000 XP scores 250. A 20 minute win with 4,000 XP scores 200.
3. Only our own hero's XP counts for our score. Tower last hits (200 XP), hero kills (150 XP), and creep XP all add directly.
4. Secondary XP is worth chasing only if it does not slow the win down.

## 2. The league right now

[verified, Observatory round data, 2026-10-01] The NeuralHub at DVC league is at round 3 with 16 entrants. Every entrant, including ours (`neuralhub-344d8dfce81fa5f1`), is version 1, which is the Softmax IDE starter policy. Baseline filler seats run the same starter.

[measured, 24 local games] Ten starter heroes against each other time out **24 of 24 games**. Only 2 to 4 of 22 towers fall in 20 minutes. Everyone scores 0.

So the real problem in this league is the stalemate. One hero that can reliably break a lane and kill the god turns 0 into a real score for its whole team.

## 3. Game facts we rely on

All [verified] from `polyworld/examples/gods_of_the_arena` (`sim.nim`, `content.nim`, `bots.nim`) at the commit that matches the live build, and the game README.

| Topic | Fact |
| --- | --- |
| Map | 116 x 116, map seed 54, fixed for the Competition variant. Red NE, Blue SW. Both teams can use the same team relative frame where our fort is at (105,10) and the enemy fort at (10,105). |
| Lanes | 3 lanes, each with outer (1,900 HP, 36 dmg), inner (2,600, 48), gate (3,900, 60) towers. Two guard towers (3,900, 60) sit by each god. God has 400 HP. |
| Exposure | Towers fall in order outer, inner, gate. Clearing any one lane exposes the two guards. Killing both guards exposes the god. |
| Tower AI | Fires once per second. Keeps its current target while valid. When choosing a new target it always prefers enemy creeps over heroes. So a hero hitting a tower is safe while our creeps are in its range and it is not already locked on the hero. |
| Tower range | 9, 9.5, 10 tiles for outer, inner, gate or guard. |
| Rewards | Tower or barracks last hit: 200 XP and 75 gold to the killer only. Hero kill: 150 XP, 100 gold. Creep: 15 XP pool shared by heroes within 6 tiles, last hitter gets 15% extra plus 15 gold. |
| Spells | Damage spells hit towers, barracks and the god (not just units). |
| Creeps | Each barracks spawns 3 melee and 1 ranged creep every 20 s, so 8 per lane per team per wave. |
| Shop | Only inside your own keep. Spawn room heals 20% HP and mana per second. |
| Potions | Health Potion (id 1): 30 gold, 120 HP over 10 s, broken by damage. Vitality Elixir (2): 75 gold, 90 HP instantly. Mana Potion (22): 45 gold, 90 mana over 10 s. Mana Elixir (3): 90 gold, 60 instantly. |
| Death | 9 s respawn, plus 5 s per previous death, max 60 s. Buyback costs 100 gold x deaths. |
| Vision | Heroes see 10 tiles. Enemy objects are hidden outside team vision. Terrain is readable through fog. |
| VM budget | Legacy flat API: 256 globals, 32 arrays, 4,096 array cells, 100,000 instructions and 250,000 work units per decision. A runtime error disables the hero for the rest of the match. |

Hero basics from `content.nim` (damage per basic hit at level 1, growth per level, attack period in ticks, range in tiles):

| Class | Role | Dmg | +/lvl | Period | Range | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Berserker (9) | Fighter | 53 | 8 | 20 | 1.33 | High HP, W costs 0 mana, R costs 24 mana |
| Demon Hunter (4) | Fighter | 32 | 7 | 15 | 1.25 | Fastest hero, highest attack rate |
| Ranger (1) | Carry | 31 | 6 | 18 | 5.5 | HP growth was halved in a recent patch |
| Death Knight (5) | Frontline | 30 | 6 | 28 | 1.27 | Highest HP |
| Arcanist (2) | Mage | 38 | 8 | 30 | 5.0 | Big area ultimate, low HP |
| Lich (7) | Mage | 36 | 8 | 32 | 5.5 | Biggest mana pool |
| Crossbowman (6) | Carry | 58 | 9 | 126 | 6.5 | One shot every 5.25 s, very low sustained damage |
| Vanguard Knight (0) | Frontline | 25 | 5 | 27 | 1.17 | Stun ultimate, ally heal |
| Warlock (8) | Support | 21 | 5 | 28 | 4.5 | Silence on E |
| Druid Warden (3) | Support | 21 | 4 | 30 | 4.0 | Two ally heals, root ultimate |

## 4. How the starter policy behaves (what we inherited)

The uploaded `Hero.bas` revision 1 is the official starter (`base.bas`) written in the legacy flat API. It runs a decision every 6 ticks.

| System | What it does | Verdict |
| --- | --- | --- |
| Draft | Picks the first available class whose role no teammate has. Ignores class strength. | Naive. Picks by class ID order, so it often takes Vanguard Knight or Ranger. |
| Abilities | Spends points R, W, E, Q. | Fine. |
| Observation | Scans the first 48 objects (gods, buildings, heroes) plus a rotating 48 object window of creeps. | Strong and budget safe. Kept. |
| Targeting | Score = 1000 minus 2 x distance squared, with bonuses: god +500, hero +60 minus 8 per level (+250 if low), creep +100 (+400 for a last hit), barracks +40, towers +0. | Weak for winning. Towers get no bonus, so creeps and heroes always win the comparison and towers are only hit when nothing else is near. Main cause of the stalemate. |
| Tower safety | Retreats when a tower targets it below 2/3 HP and no creeps are near. | Reactive only. No rule for when it is safe to hit a tower. |
| Power estimate | Sums level + 2 for heroes within 10 tiles (allies) or 12 tiles (enemies), +2 for enemies with mana, +1 or +2 per visible enemy item. | Crude but usable. |
| Spells | Casts any damage spell at the current target when in range. Saves the last charge of a recharging spell against creeps. | Wastes ultimates on creeps, because a full ultimate reports zero recharge time. |
| Healing | Self heals, Druid heals the most hurt ally, Vanguard Aegis on self. | Fine. |
| Items | Boots, potions, portals, then one role item. | Low damage. Spends a slot on boots. |
| Retreat | Below 25% HP walks home to spawn, heals to 90%, walks back. Uses a portal scroll if it has one. | Very slow. Round trips take about a minute. |
| Buyback | Buys back the instant it can afford it. | Wasteful when the respawn is only a few seconds. |
| Dodge | Steps 3 tiles away from hostile area warnings within 3 tiles that land in under 3 s. | Fine. |
| Kiting | Ranged heroes step back after a swing when an enemy hero faces them within 2 tiles. | Fine. |
| Macro | Before level 6: two roles per side lane corner, fighter mid. From level 6: everyone walks to map center, then attack moves at the enemy fort. | Everyone piles into mid and brawls. Nobody commits to a lane. |
| Camps | Farms nearby camps between fights at tier gated levels. | Fine as filler. |

## 5. Current strategy (v2 line)

1. **Draft a pusher.** Preference: Berserker, Demon Hunter, Ranger, Death Knight, Arcanist, Lich, Vanguard Knight, Warlock, Druid Warden, Crossbowman. [belief, to be measured per class]
2. **Commit to one lane.** Walk the lane toward the next enemy structure and remember which ones are dead.
3. **Creep cover rule.** Hit a tower only when at least two of our creeps are inside its range and it is not targeting us, or when we can finish it (200 XP). Otherwise hold about 11.5 tiles back and fight whatever comes.
4. **Objective scores.** God +3000, safe tower +700 (+500 near death), barracks +350, killable hero bonuses.
5. **Spells on value.** Ultimates only on heroes, towers, barracks and the god. Keep ultimate mana when enemy heroes are near.
6. **Recover in lane.** Below 30% HP drink potions a few tiles back instead of walking home. Go home only when out of potions.
7. **Items.** Potions and one portal scroll first, then damage (Battle Axe, Rune Crossbow, Sunsteel) and Knight Armor. Mages take the Spellbook and mana potions.
8. **Buyback** only when more than 12 s of respawn remain.

## 6. Open questions

1. Which lane is best to push alone? The baseline sends everyone mid after level 6, so a side lane may be quieter. [testing]
2. Which class gives the highest Glory in this role? [to test]
3. Is a 3 tick decision period worth it over 6? [to test]
4. Does buying back early help or hurt? [to test]
5. When other students improve their bots, does a solo push still work, or do we need to group?

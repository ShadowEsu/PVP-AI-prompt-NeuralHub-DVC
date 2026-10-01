' Neural Viking GOTA policy v2 (Preston Susanto, NeuralHub at DVC)
' Built from the official starter. Goal: win fast (Emmett's Glory pays
' winning heroes XP per minute, losers and timeouts score zero).
' Core idea: starter teams almost never kill towers, so every match times
' out. This hero drafts a strong pusher, walks one lane, lets its creep wave
' tank enemy towers, takes tower last hits (200 XP each), then guards and god.
' Object indices last only for this decision. IDs may be remembered.

dim owned(22)
dim inventorySlot(22)
dim allyIds(9)
dim seenMaxHp(9)
dim castRange(3)
dim castDelay(3)
dim castGround(3)
dim castMinimum(3)
dim laneX(11)
dim laneY(11)
dim laneDead(11)
dim laneSeen(11)
dim pref(9)

' ---- Tunable strategy constants (edited by experiments) ----
sub config()
  pushLane = 1
  thinkTicks = 3
  retreatPct = 30
  pref(0) = Berserker
  pref(1) = DemonHunter
  pref(2) = Ranger
  pref(3) = DeathKnight
  pref(4) = Arcanist
  pref(5) = Lich
  pref(6) = VanguardKnight
  pref(7) = Warlock
  pref(8) = DruidWarden
  pref(9) = Crossbowman
end sub

sub chooseHero()
  if draftTurnId <> selfId then
    exit sub
  end if
  config()
  for pick = 0 to 9
    if heroAvailable(pref(pick)) then
      accepted = draftHero(pref(pick))
      if accepted then
        exit sub
      end if
    end if
  next pick
end sub

sub learnAbilities()
  for upgrade = 1 to 4
    if abilityPoints() = 0 then
      exit sub
    end if
    upgradeSlot = -1
    upgradeScore = -1
    for spellSlot = 0 to 3
      if abilityLevel(spellSlot) < abilityMaxLevel(spellSlot) then
        if canLevelAbility(spellSlot) then
          ' R first, then W (tower and hero damage), then E, then Q.
          score = spellSlot
          if spellSlot = 1 then
            score = 2
          elseif spellSlot = 2 then
            score = 1
          end if
          if abilityLevel(spellSlot) = 0 then
            score = score + 4
          end if
          if score > upgradeScore then
            upgradeScore = score
            upgradeSlot = spellSlot
          end if
        end if
      end if
    next spellSlot
    if upgradeSlot < 0 then
      exit sub
    end if
    accepted = levelAbility(upgradeSlot)
  next upgrade
end sub

sub setupLanes()
  ' Enemy structures in our team frame for the 116x116 league map.
  ' Lane 0 west (bottom row then left column), 1 mid, 2 east.
  laneX(0) = 7
  laneY(0) = 46
  laneX(1) = 7
  laneY(1) = 77
  laneX(2) = 4
  laneY(2) = 86
  laneX(3) = 51
  laneY(3) = 73
  laneX(4) = 34
  laneY(4) = 86
  laneX(5) = 19
  laneY(5) = 96
  laneX(6) = 95
  laneY(6) = 104
  laneX(7) = 46
  laneY(7) = 104
  laneX(8) = 29
  laneY(8) = 111
  laneX(9) = 16
  laneY(9) = 106
  laneX(10) = 9
  laneY(10) = 99
  laneX(11) = 10
  laneY(11) = 105
  for slot = 0 to 11
    laneDead(slot) = 0
    laneSeen(slot) = -1000
  next slot
end sub

sub readObject(index)
  id = objectId(index)
  kind = objectKind(index)
  team = objectTeam(index)
  hp = objectHp(index)
  if hp <= 0 then
    exit sub
  end if
  x = originX + side * objectX(index)
  y = originY + side * objectY(index)
  dx = x - myX
  dy = y - myY
  distance = dx * dx + dy * dy
  if kind = 6 then
    if objectReturning(index) or objectAlive(index) = 0 then
      exit sub
    end if
    if objectTarget(index) = selfId and distance < campHitDistance then
      ' A camp we walked past is attacking us.
      campHitDistance = distance
      campHitId = id
      campHitIndex = index
      campHitHp = hp
      campHitX = x
      campHitY = y
    end if
    camp = objectCamp(index)
    tier = campTier(camp)
    campDx = originX + side * campX(camp) - myX
    campDy = originY + side * campY(camp) - myY
    if campDx * campDx + campDy * campDy > 64 then
      exit sub
    end if
    enoughHealth = selfHp * 10 >= selfMaxHp * 7
    if selfTarget = id then
      enoughHealth = selfHp * 10 >= selfMaxHp * 4
    end if
    if camp >= 0 and camp < campCount() and enoughHealth then
      if selfLevel >= 1 + (tier - 1) * 3 and distance <= 36 then
        score = 100 - distance
        if objectLeader(index) then
          score = score - 10
        end if
        if selfTarget = id then
          score = score + 100
        end if
        if score > campScore then
          campScore = score
          campIndex = index
          campId = id
          campHp = hp
          campXpos = x
          campYpos = y
          campDistance = distance
        end if
      end if
    end if
    exit sub
  end if
  if team = selfTeam then
    if kind = 1 then
      homeX = x
      homeY = y
    elseif kind = 4 then
      ' Portal anchor: the allied tower closest to our push objective.
      dx = x - pushX
      dy = y - pushY
      score = dx * dx + dy * dy
      if score < forwardDistance then
        forwardDistance = score
        forwardX = x
        forwardY = y
      end if
    elseif kind = 2 then
      allyIds(allies) = id
      allies = allies + 1
      class = objectClass(index)
      if hp > seenMaxHp(class) then
        seenMaxHp(class) = hp
      end if
      if distance <= 100 then
        friendlyPower = friendlyPower + objectLevel(index) + 2
      end if
      missing = seenMaxHp(class) - hp
      if distance <= healRange * healRange and missing > healMissing then
        healMissing = missing
        healId = id
      end if
    elseif kind = 3 then
      if distance <= 64 then
        tanks = tanks + 1
      end if
      if towerId <> 0 then
        dx = x - towerX
        dy = y - towerY
        if dx * dx + dy * dy <= 72 then
          creepsAtTower = creepsAtTower + 1
        end if
      end if
    end if
    exit sub
  end if
  ' Remember enemy structures we can see so the lane plan stays current.
  if kind = 4 or kind = 1 then
    for slot = 0 to 11
      dx = x - laneX(slot)
      dy = y - laneY(slot)
      if dx * dx + dy * dy <= 9 then
        laneSeen(slot) = worldTick
        laneDead(slot) = 0
      end if
    next slot
  end if
  if kind = 2 and distance <= 144 then
    enemyPower = enemyPower + objectLevel(index) + 2
    if objectMana(index) >= 25 and objectSilenceTicks(index) = 0 then
      enemyPower = enemyPower + 2
    end if
  end if
  if kind = 2 or kind = 3 then
    if distance < threatDistance then
      threatDistance = distance
    end if
  end if
  if distance > 324 or objectAlive(index) = 0 then
    exit sub
  end if
  target = objectTarget(index)
  if kind = 4 then
    if target = selfId then
      towerAggro = 1
    end if
    if distance < towerDistance then
      towerDistance = distance
      towerId = id
      towerX = x
      towerY = y
      towerHp = hp
      towerTarget = target
    end if
    ' Towers are scored after the scan once we know creep cover.
    exit sub
  end if
  score = 1000 - distance * 2
  if kind = 1 then
    score = score + 3000
  elseif kind = 5 then
    score = score + 350
  elseif kind = 2 then
    score = score + 150 - objectLevel(index) * 8
    if hp < selfAttackDamage * 4 then
      score = score + 350
    end if
    if hp < selfAttackDamage * 2 then
      score = score + 300
    end if
  elseif kind = 3 then
    score = score + 100
    if hp <= selfAttackDamage and selfAttackCooldown <= tickRate \ 2 then
      score = score + 400
    end if
  end if
  if target = selfId then
    score = score + 40
  end if
  if id = selfTarget then
    score = score + 60
  end if
  if id = blockedId and worldTick < blockedUntil then
    exit sub
  end if
  if score > bestScore then
    bestScore = score
    bestIndex = index
    bestId = id
    bestKind = kind
    bestHp = hp
    bestX = x
    bestY = y
    bestDistance = distance
  end if
end sub

sub pickPush()
  ' Next enemy structure along our lane, then the nearer guard, then the god.
  pushSlot = 11
  for tier = 0 to 2
    slot = pushLane * 3 + tier
    if laneDead(slot) = 0 and pushSlot = 11 then
      pushSlot = slot
    end if
  next tier
  if pushSlot = 11 then
    if laneDead(9) = 0 then
      pushSlot = 9
    elseif laneDead(10) = 0 then
      pushSlot = 10
    end if
  end if
  pushX = laneX(pushSlot)
  pushY = laneY(pushSlot)
end sub

sub observe()
  campScore = -10000
  campId = 0
  campHitId = 0
  campHitDistance = 1000000
  bestScore = -10000
  bestId = 0
  bestKind = 0
  bestDistance = 1000000
  threatDistance = 1000000
  forwardDistance = 1000000
  towerDistance = 1000000
  towerId = 0
  towerTarget = 0
  creepsAtTower = 0
  friendlyPower = 0
  enemyPower = 0
  allies = 0
  tanks = 0
  towerAggro = 0
  healId = selfId
  healMissing = selfMaxHp - selfHp
  seenMaxHp(selfClass) = selfMaxHp
  objects = objectCount()
  for scan = 0 to 95
    index = scan
    if scan >= 48 then
      index = scan + scanOffset
    end if
    if index < objects then
      readObject(index)
    end if
  next scan
  if targetIndex >= 48 and targetIndex < objects and selfTarget <> 0 then
    if targetIndex < 48 + scanOffset or targetIndex >= 96 + scanOffset then
      if objectId(targetIndex) = selfTarget then
        readObject(targetIndex)
      end if
    end if
  end if
  scanOffset = scanOffset + 48
  if scanOffset >= objects - 48 then
    scanOffset = 0
  end if
  ' A structure we stand next to but cannot see this decision is gone.
  for slot = 0 to 10
    if laneDead(slot) = 0 and laneSeen(slot) <> worldTick then
      dx = laneX(slot) - myX
      dy = laneY(slot) - myY
      if dx * dx + dy * dy <= 49 then
        laneDead(slot) = 1
      end if
    end if
  next slot
  ' Tower decision: hit it only while our creeps hold its attention, or to
  ' steal a near-certain last hit. Otherwise stay out of its range.
  towerSafe = 0
  towerDanger = 0
  if towerId <> 0 then
    finishing = towerHp <= selfAttackDamage * 2 and selfHp * 10 >= selfMaxHp * 4
    if towerTarget <> selfId and creepsAtTower >= 2 then
      towerSafe = 1
    elseif finishing then
      towerSafe = 1
    elseif towerTarget = selfId and creepsAtTower >= 1 and selfHp * 10 >= selfMaxHp * 7 then
      towerSafe = 1
    end if
    if towerSafe then
      score = 1000 - towerDistance * 2 + 700
      if towerHp <= selfAttackDamage * 4 then
        score = score + 500
      end if
      if score > bestScore then
        bestScore = score
        bestId = towerId
        bestKind = 4
        bestHp = towerHp
        bestX = towerX
        bestY = towerY
        bestDistance = towerDistance
        bestIndex = -1
      end if
    elseif towerDistance <= 121 then
      towerDanger = 1
    end if
  end if
  if bestId = 0 and campId <> 0 and towerAggro = 0 and enemyPower = 0 then
    bestId = campId
    bestIndex = campIndex
    bestKind = 6
    bestHp = campHp
    bestX = campXpos
    bestY = campYpos
    bestDistance = campDistance
  end if
  campFlee = 0
  if campHitId <> 0 and bestKind <> 2 and bestKind <> 1 then
    if selfHp * 2 >= selfMaxHp then
      bestId = campHitId
      bestIndex = campHitIndex
      bestKind = 6
      bestHp = campHitHp
      bestX = campHitX
      bestY = campHitY
      bestDistance = campHitDistance
    else
      campFlee = 1
    end if
  end if
  ' Never chase a unit that stands inside an unsafe enemy tower's range.
  if bestId <> 0 and towerId <> 0 and towerSafe = 0 and bestKind <> 1 then
    dx = bestX - towerX
    dy = bestY - towerY
    if dx * dx + dy * dy <= 100 then
      if bestKind <> 2 or bestHp > selfAttackDamage * 2 then
        bestId = 0
        bestKind = 0
      end if
    end if
  end if
  if bestId = 0 then
    exit sub
  end if
  velocityX = 0
  velocityY = 0
  targetHeld = 0
  aimedAtUs = 0
  if bestIndex < 0 then
    exit sub
  end if
  targetIndex = bestIndex
  velocityX = (side * objectVelX(bestIndex) \ 100) / (worldScale \ 100)
  velocityY = (side * objectVelY(bestIndex) \ 100) / (worldScale \ 100)
  targetHeld = objectStunTicks(bestIndex)
  targetRoot = objectRootTicks(bestIndex)
  if targetRoot > targetHeld then
    targetHeld = targetRoot
  end if
  facingX = (side * objectFacingX(bestIndex) \ 100) / (worldScale \ 100)
  facingY = (side * objectFacingY(bestIndex) \ 100) / (worldScale \ 100)
  aimedAtUs = facingX * (myX - bestX) + facingY * (myY - bestY)
end sub

sub buy(id, price, quantity)
  if owned(id) >= quantity or budget < price then
    exit sub
  end if
  if owned(id) = 0 and emptySlots = 0 then
    exit sub
  end if
  accepted = buyItem(id)
  if accepted then
    if owned(id) = 0 then
      emptySlots = emptySlots - 1
    end if
    owned(id) = owned(id) + 1
    budget = budget - price
    for boughtSlot = 0 to 5
      if itemId(boughtSlot) = id then
        inventorySlot(id) = boughtSlot
      end if
    next boughtSlot
  end if
end sub

sub inventory()
  for id = 0 to 22
    owned(id) = 0
    inventorySlot(id) = -1
  next id
  emptySlots = 0
  for itemSlot = 0 to 5
    id = itemId(itemSlot)
    if id = 0 then
      emptySlots = emptySlots + 1
    else
      owned(id) = itemCount(itemSlot)
      inventorySlot(id) = itemSlot
      if itemCooldown(itemSlot) = 0 and inOwnSpawn() = 0 then
        consume = 0
        if id = 1 and selfMaxHp - selfHp >= 120 then
          consume = worldTick - hurtTick > tickRate
        elseif id = 2 and selfHp * 5 < selfMaxHp * 2 then
          consume = 1
        elseif id = 22 and selfMaxMana - selfMana >= 90 then
          consume = worldTick - hurtTick > tickRate
        elseif id = 3 and selfMana * 3 < selfMaxMana then
          consume = bestId <> 0
        end if
        if consume then
          accepted = useItem(itemSlot)
          if accepted then
            owned(id) = owned(id) - 1
            if owned(id) = 0 then
              emptySlots = emptySlots + 1
              inventorySlot(id) = -1
            end if
          end if
        end if
      end if
    end if
  next itemSlot
  if canShop() = 0 then
    exit sub
  end if
  ' Damage kills towers and heroes; one health stack and portals keep tempo.
  budget = selfGold
  buy(1, 30, 3)
  buy(21, 100, 1)
  if role = 2 or role = 3 then
    buy(20, 190, 1)
    buy(21, 100, 1)
    buy(18, 180, 1)
    buy(16, 160, 1)
    buy(22, 45, 2)
  else
    buy(18, 180, 1)
    buy(21, 100, 1)
    buy(19, 180, 1)
    buy(16, 160, 1)
    buy(13, 150, 1)
  end if
  buy(1, 30, 4)
  buy(21, 100, 2)
end sub

sub dodgeWarnings()
  dodge = 0
  warnings = spellCount()
  for warning = warningOffset to warningOffset + 11
    if warning < warnings then
      spell = spellAbility(warning)
      caster = spellCasterId(warning)
      hostile = caster <> selfId
      for ally = 0 to allies - 1
        if caster = allyIds(ally) then
          hostile = 0
        end if
      next ally
      if spell = 0 or spell = 2 or spell = 8 or spell = 12 then
        hostile = 0
      end if
      if spell = 13 or spell = 14 or spell = 16 or spell = 20 then
        hostile = 0
      end if
      if spell = 32 or spell = 36 then
        hostile = 0
      end if
      impact = spellImpactTick(warning) - worldTick
      warningX = originX + side * spellX(warning)
      warningY = originY + side * spellY(warning)
      dx = myX - warningX
      dy = myY - warningY
      if hostile and impact > 0 and impact <= tickRate * 3 then
        if dx * dx + dy * dy <= 9 then
          dodge = 1
          dodgeX = myX + 3
          dodgeY = myY + 3
          if dx < 0 then
            dodgeX = myX - 3
          end if
          if dy < 0 then
            dodgeY = myY - 3
          end if
        end if
      end if
    end if
  next warning
  warningOffset = warningOffset + 12
  if warningOffset >= warnings then
    warningOffset = 0
  end if
end sub

sub moveTo(goalX, goalY, marching)
  if selfRootTicks > 0 then
    exit sub
  end if
  if goalX = orderX and goalY = orderY and marching = orderMarch then
    if worldTick - orderTick < tickRate * 2 then
      exit sub
    end if
  end if
  routeScore = 1000000
  routeFound = 0
  floorHeight = terrainHeight(selfX, selfY)
  for offsetY = -1 to 1
    for offsetX = -1 to 1
      tileX = goalX + offsetX
      tileY = goalY + offsetY
      worldTileX = originX + side * tileX
      worldTileY = originY + side * tileY
      if tileX >= 0 and tileX < mapWidth then
        if tileY >= 0 and tileY < mapHeight then
          open = terrainWalkable(worldTileX, worldTileY)
          ground = terrainKind(worldTileX, worldTileY)
          height = terrainHeight(worldTileX, worldTileY)
          depth = terrainWaterDepth(worldTileX, worldTileY)
          if open = 0 then
            for layer = 0 to mapLayers - 1
              worldLayer = layer
              if layer = RedFortLayer or layer = BlueFortLayer then
                worldLayer = layer + selfTeam * (RedFortLayer + BlueFortLayer - 2 * layer)
              end if
              if terrainWalkableAt(worldTileX, worldTileY, worldLayer) then
                open = 1
                ground = terrainKindAt(worldTileX, worldTileY, worldLayer)
                height = terrainHeightAt(worldTileX, worldTileY, worldLayer)
                depth = terrainWaterDepthAt(worldTileX, worldTileY, worldLayer)
                exit for
              end if
            next layer
          end if
          if open and ground <> TerrainNone then
            elevation = height - floorHeight
            if elevation < 0 then
              elevation = -elevation
            end if
            score = (offsetX * offsetX + offsetY * offsetY) * 20
            score = score + depth * 2 + elevation
            if ground = TerrainRoad then
              score = score - 5
            end if
            if score < routeScore then
              routeScore = score
              routeX = tileX
              routeY = tileY
              routeFound = 1
            end if
          end if
        end if
      end if
    next offsetX
  next offsetY
  if routeFound = 0 then
    exit sub
  end if
  if marching then
    accepted = attackMove(originX + side * routeX, originY + side * routeY)
  else
    accepted = walkTo(originX + side * routeX, originY + side * routeY)
  end if
  actionError = lastActionError()
  orderTick = worldTick
  if accepted then
    orderX = goalX
    orderY = goalY
    orderMarch = marching
  elseif actionError = ActionNoRoute then
    blockedId = bestId
    blockedUntil = worldTick + tickRate * 3
  end if
end sub

sub spells()
  if selfSilenceTicks > 0 then
    exit sub
  end if
  for spellSlot = 0 to 3
    charges = abilityCharges(spellSlot)
    recharge = abilityRecharge(spellSlot)
    damage = abilityDamage(spellSlot)
    healing = abilityHeal(spellSlot)
    restore = abilityRestore(spellSlot)
    cost = abilityManaCost(spellSlot)
    if abilityLevel(spellSlot) > 0 and charges > 0 then
      if abilityCooldown(spellSlot) = 0 and selfMana >= cost then
        castId = 0
        if healing > 0 and healMissing >= healing \ 2 then
          if selfClass = DruidWarden and spellSlot > 0 then
            castId = healId
          elseif selfClass = VanguardKnight and spellSlot = 2 then
            castId = selfId
          elseif selfMaxHp - selfHp >= healing \ 2 then
            castId = selfId
          end if
        elseif restore > 0 and selfMaxMana - selfMana >= restore then
          castId = selfId
        elseif damage > 0 and bestId <> 0 and bestKind <> 6 then
          if bestDistance <= castRange(spellSlot) * castRange(spellSlot) then
            if bestDistance >= castMinimum(spellSlot) * castMinimum(spellSlot) then
              if bestKind = 2 or bestKind = 1 or bestKind = 4 or bestKind = 5 then
                ' Heroes, towers, barracks and the god always earn spells.
                castId = bestId
              elseif spellSlot < 3 and charges > 1 then
                castId = bestId
              elseif spellSlot < 3 and bestHp <= damage and bestHp > selfAttackDamage then
                castId = bestId
              end if
              ' Keep enough mana for the ultimate when a hero fight is near.
              if spellSlot < 3 and bestKind = 3 and enemyPower > 0 then
                if selfMana - cost < abilityManaCost(3) then
                  castId = 0
                end if
              end if
            end if
          end if
        end if
        if castId <> 0 then
          if castId = bestId and castGround(spellSlot) and bestIndex >= 0 then
            leadX = velocityX * castDelay(spellSlot)
            leadY = velocityY * castDelay(spellSlot)
            if targetHeld >= castDelay(spellSlot) then
              leadX = 0
              leadY = 0
            end if
            if leadX > 2 then
              leadX = 2
            elseif leadX < -2 then
              leadX = -2
            end if
            if leadY > 2 then
              leadY = 2
            elseif leadY < -2 then
              leadY = -2
            end if
            aimX = bestX + leadX
            aimY = bestY + leadY
            if aimX >= 0 and aimX < mapWidth - 1 then
              if aimY >= 0 and aimY < mapHeight - 1 then
                accepted = castPoint(spellSlot, originX + side * aimX, originY + side * aimY)
                if accepted then
                  exit sub
                end if
              end if
            end if
          end if
          accepted = castTarget(spellSlot, castId)
          if accepted then
            exit sub
          end if
        end if
      end if
    end if
  next spellSlot
end sub

if drafting then
  chooseHero()
  end
end if

if selfHp <= 0 then
  ' Buy back only when the wait is long enough to cost real tempo.
  price = buybackPrice()
  if price > 0 and selfGold >= price and selfRespawnTicks > tickRate * 12 then
    accepted = buyback()
  end if
  initialized = 0
  end
end if
if selfChannelTicks > 0 or selfStunTicks > 0 then
  end
end if
if worldTick < nextThink then
  end
end if
side = 1 - selfTeam * 2
originX = selfTeam * (mapWidth - 1)
originY = selfTeam * (mapHeight - 1)
myX = originX + side * selfX
myY = originY + side * selfY

if setupDone = 0 then
  setupDone = 1
  config()
  setupLanes()
  print "CLASS "; selfClass
end if
nextThink = worldTick + thinkTicks
role = heroRole(selfClass)
attackRange = (selfAttackRange \ 100) / (worldScale \ 100)
speed = (selfMoveSpeed \ 100) / (worldScale \ 100)

if initialized = 0 then
  initialized = 1
  spawnX = myX
  spawnY = myY
  homeX = myX
  homeY = myY
  previousHp = selfHp
  progressTick = worldTick
  previousX = myX
  previousY = myY
  retreating = 0
  castRange(0) = 0
  castRange(1) = 1.5
  castRange(2) = 2.5
  castRange(3) = 2
  castDelay(2) = 24
  castDelay(3) = 24
  healRange = 4
  for spellSlot = 0 to 3
    castGround(spellSlot) = spellSlot >= 2
    castMinimum(spellSlot) = 0
  next spellSlot
  if selfClass = VanguardKnight then
    healRange = 7 / 3
    castRange(2) = 7 / 3
    castRange(3) = 11 / 6
    castDelay(2) = 12
    castDelay(3) = 6
  elseif selfClass = Ranger then
    castRange(0) = 7
    castRange(1) = 6
    castRange(2) = 6.5
    castRange(3) = 8
  elseif selfClass = Arcanist then
    castRange(1) = 5.5
    castRange(2) = 6
    castRange(3) = 7
    castDelay(2) = 48
    castDelay(3) = 72
  elseif selfClass = DruidWarden then
    castRange(1) = 4
    castRange(2) = 4
    castRange(3) = 10 / 3
  elseif selfClass = DemonHunter then
    castRange(2) = 2
    castRange(3) = 5
    castDelay(2) = 6
    castGround(3) = 0
  elseif selfClass = DeathKnight then
    castRange(2) = 8 / 3
    castRange(3) = 7 / 3
    castDelay(3) = 12
    castGround(3) = 0
    castMinimum(3) = 2 / 3
  elseif selfClass = Crossbowman then
    castRange(0) = 7
    castRange(1) = 20 / 3
    castRange(2) = 6
    castRange(3) = 7.5
    castDelay(2) = 12
  elseif selfClass = Lich then
    castRange(0) = 6
    castRange(1) = 20 / 3
    castRange(2) = 5
    castRange(3) = 6.5
    castGround(3) = 0
  elseif selfClass = Warlock then
    castRange(1) = 14 / 3
    castRange(2) = 4
    castRange(3) = 5
    castGround(3) = 0
  elseif selfClass = Berserker then
    castRange(3) = 13 / 6
    castDelay(2) = 12
    castDelay(3) = 48
  end if
end if

if selfHp < previousHp then
  hurtTick = worldTick
end if
previousHp = selfHp
if selfAttacksLanded <> previousHits or myX <> previousX or myY <> previousY then
  progressTick = worldTick
end if
previousHits = selfAttacksLanded
previousX = myX
previousY = myY
if worldTick - progressTick > tickRate * 6 and selfTarget <> 0 then
  blockedId = selfTarget
  blockedUntil = worldTick + tickRate * 3
  progressTick = worldTick
end if

learnAbilities()
pickPush()
observe()
inventory()
spells()
dodgeWarnings()

if selfHp * 100 < selfMaxHp * retreatPct then
  ' Potions heal far faster than a walk home and back.
  if owned(1) + owned(2) > 0 and selfHp * 100 >= selfMaxHp * 15 then
    recovering = 1
  else
    retreating = 1
  end if
end if
if recovering then
  if selfHp * 10 >= selfMaxHp * 7 or owned(1) + owned(2) = 0 then
    recovering = 0
  end if
end if
if bestKind = 6 and selfHp * 10 < selfMaxHp * 4 then
  retreating = 1
end if
if selfMana * 8 < selfMaxMana and bestId = 0 and role = 2 then
  retreating = 1
end if
if inOwnSpawn() then
  if selfHp * 10 < selfMaxHp * 9 or selfMana * 10 < selfMaxMana * 8 then
    moveTo(spawnX, spawnY, 0)
    end
  end if
  retreating = 0
  recovering = 0
end if

if campFlee and retreating = 0 then
  ' Walk (never attack move) away from the camp until it leashes.
  moveTo(myX + (myX - campHitX) * 2, myY + (myY - campHitY) * 2, 0)
  end
end if
if dodge and selfRootTicks = 0 then
  moveTo(dodgeX, dodgeY, 0)
  end
end if
if retreating then
  if owned(21) > 0 and selfPortalCooldown = 0 and selfRootTicks = 0 then
    dx = myX - homeX
    dy = myY - homeY
    if dx * dx + dy * dy > 400 and threatDistance > 100 then
      accepted = useItemAt(inventorySlot(21), originX + side * spawnX, originY + side * spawnY)
      if accepted then
        end
      end if
    end if
  end if
  moveTo(spawnX, spawnY, 0)
  end
end if

if recovering and retreating = 0 then
  ' Step back toward home, out of the fight, drink, then rejoin the push.
  dx = homeX - myX
  dy = homeY - myY
  reach = dx * dx + dy * dy
  if reach > 49 and reach < 30000 then
    reach = sqrt(reach)
    moveTo(myX + floor(dx * 6 / reach), myY + floor(dy * 6 / reach), 0)
  else
    moveTo(homeX, homeY, 0)
  end if
  end
end if

' Leave tower range when it is shooting us without creep cover.
if towerAggro and towerSafe = 0 then
  moveTo(homeX, homeY, 0)
  end
end if
if enemyPower > friendlyPower + 6 and threatDistance < 64 then
  if selfHp * 4 < selfMaxHp * 3 then
    moveTo(homeX, homeY, 0)
    end
  end if
end if

if bestId <> 0 then
  if bestKind = 2 and aimedAtUs > 0 and attackRange >= 3 then
    if bestDistance < 4 and selfAttackCooldown > tickRate \ 2 then
      if selfAttacksLanded > 0 and speed > 0 then
        kiteStep = (selfMoveSpeed * tickRate) \ worldScale
        if kiteStep < 1 then
          kiteStep = 1
        elseif kiteStep > 4 then
          kiteStep = 4
        end if
        kiteX = myX + kiteStep
        kiteY = myY + kiteStep
        if bestX >= myX then
          kiteX = myX - kiteStep
        end if
        if bestY >= myY then
          kiteY = myY - kiteStep
        end if
        moveTo(kiteX, kiteY, 0)
        end
      end if
    end if
  end if
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
    if accepted = 0 then
      blockedId = bestId
      blockedUntil = worldTick + tickRate * 3
    else
      orderTick = 0
    end if
  end if
  end
end if

' Macro: march our lane. Wait outside tower range until creeps arrive.
goalX = pushX
goalY = pushY
march = 1
dx = myX - pushX
dy = myY - pushY
gap = dx * dx + dy * dy
if pushSlot < 11 and gap < 225 then
  if towerId = 0 or towerSafe = 0 then
    ' Attack move would auto target the tower, so walk to the hold point.
    march = 0
    ' Hold 11.5 tiles back from the tower along our approach.
    if gap > 0 then
      reach = sqrt(gap)
      goalX = pushX + floor(dx * 12 / reach)
      goalY = pushY + floor(dy * 12 / reach)
    end if
    if towerId = 0 and laneSeen(pushSlot) < worldTick - tickRate * 2 and gap <= 49 then
      goalX = pushX
      goalY = pushY
    end if
  end if
end if
if canShop() and owned(21) > 0 and selfPortalCooldown = 0 then
  dx = myX - forwardX
  dy = myY - forwardY
  if forwardDistance < 1000000 and dx * dx + dy * dy > 400 then
    if threatDistance > 144 then
      accepted = useItemAt(inventorySlot(21), originX + side * forwardX, originY + side * forwardY)
      if accepted then
        end
      end if
    end if
  end if
end if
if towerDanger then
  march = 0
end if
moveTo(goalX, goalY, march)

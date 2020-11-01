--[[ TODO
        - enable range detection in battlegrounds
            - change roster to key off group unit ID so that "WA_HEALERWATCH_UPDATE" event handler can check if unit is in range
                - "PLAYER_ROLES_ASSIGNED" event handler iterates through group unit IDs, so use that as the key
                - handlers for other events will check if the event unit ID exists as a key in the roster
                    - if it isn't, ignore the event
                        - this helps deduplicate events
                        - this also replaces the check on whether the event unit ID is a healer
        - is 'UNIT_POWER_FREQUENT' worth the performance cost?
        - would it be more efficient or otherwise better to retrieve mana values on each valid update event?
]]

-- init
C_ChatInfo.RegisterAddonMessagePrefix("HealerWatch_WA")
aura_env.playerNameWithRealm = GetUnitName("player") .. '-' .. GetRealmName()

function aura_env.resetRoster(self)
    -- Reset the 'aura_env' state.

    -- Note that we use unit GUID as keys to deduplicate units (e.g., between
    -- 'party1' and 'target').

    -- A dictionary that maps from unit GUID to a mana value.
    self.healerMana = {}

    -- The number of entries in 'self.healerMana'.
    self.numHealers = 0

    -- A set of unit GUIDs for dead healers in the group.
    self.deadHealers = {}

    -- The number of entries in 'self.deadHealers'.
    self.numDeadHealers = 0
end

function aura_env.cacheHealerState(self, unit)
    -- Save 'unit's mana into 'self.healerMana'.  If 'unit' is dead, save a
    -- value of 0.  If 'unit' is dead and is not already in 'self.deadHealers',
    -- insert 'unit' into 'self.deadHealers' and increment
    -- 'self.numDeadHealers'.  If 'unit' is alive and still in
    -- 'self.deadHealers', remove 'unit' from 'self.deadHealers' and decrement
    -- 'self.numDeadHealers'.

    local unitGuid = UnitGUID(unit)

    if UnitIsDeadOrGhost(unit) then
        self.healerMana[unitGuid] = 0

        if self.deadHealers[unitGuid] == nil then
            self.deadHealers[unitGuid] = true
            self.numDeadHealers = self.numDeadHealers + 1
        end
    else
        if self.canAccessUnitMana(unit) then
            local mana = (100 * UnitPower(unit, Enum.PowerType.Mana)
                              / UnitPowerMax(unit, Enum.PowerType.Mana))

            self.healerMana[unitGuid] = mana
        end

        if self.deadHealers[unitGuid] ~= nil then
            self.deadHealers[unitGuid] = nil
            self.numDeadHealers = aura_env.numDeadHealers - 1
        end
    end
end

function aura_env.getHealerUnitIdFromName(fullUnitName)
    -- Return the unit ID for the specified 'fullUnitName' if he/she is a
    -- healer in our group.  Otherwise, return 'nil'.  'fullUnitName' must
    -- include the player's realm name.

    -- Ignore the unit if he/she is not in our group.

    local unit
    for groupUnit in WA_IterateGroupMembers() do
        local name, realm = UnitName(groupUnit)

        if realm == nil then
            realm = GetRealmName()
        end

        if (name .. "-" .. realm) == fullUnitName then
            unit = groupUnit
            break
        end
    end

    if unit == nil then
        return nil
    end

    -- Ignore the unit if he/she is not a healer.

    if UnitGroupRolesAssigned(unit) ~= "HEALER" then
        return nil
    end

    return unit
end

function aura_env.canAccessUnitMana(unit)
    -- Return 'true' if we can query for 'unit's mana.  Otherwise, return
    -- 'false'.

    return (Enum.PowerType.Mana == UnitPowerType(unit)
            or UnitGUID(unit) == UnitGUID("player"))
end

function aura_env.isGroupUnitId(unit)
    -- Return 'true' if the specified 'unit' is "player" or matches the string
    -- value for a group member (e.g., "party2"), not including pets.
    -- Otherwise, return false.

    -- Applying this filter allows us to reduce the processing of redundant
    -- events (e.g., "partyN" vs. "nameplateM").

    return unit == "player"
        or unit:find("party%d") == 0
        or unit:find("raid%d") == 0
end

-- trigger1: PLAYER_ROLES_ASSIGNED
function(event)
    -- Determine which unit IDs in the group are healers.  Save them into
    -- 'aura_env.healerMana' and update 'aura_env.numHealers'.

    aura_env:resetRoster()

    for unit in WA_IterateGroupMembers() do
        if UnitGroupRolesAssigned(unit) == "HEALER" then
            aura_env.numHealers = aura_env.numHealers + 1

            -- Default the healer's mana to 100%.  This should generally be a
            -- safer assumed value than 0% for this event, since this event is
            -- most likely to be fired while out of combat.

            aura_env.healerMana[UnitGUID(unit)] = 100

            aura_env:cacheHealerState(unit)
        end
    end

    WeakAuras.ScanEvents("WA_HEALERWATCH_UPDATE", event)
end

-- trigger2: UNIT_POWER_UPDATE
function(event, unit)
    if UnitGroupRolesAssigned(unit) ~= "HEALER"
    or not aura_env.canAccessUnitMana(unit) then
        return
    end

    if not aura_env.isGroupUnitId(unit) then
        return
    end

    aura_env:cacheHealerState(unit)
    WeakAuras.ScanEvents("WA_HEALERWATCH_UPDATE", event, unit)
end

-- trigger3: UNIT_HEALTH
function(event, unit)
    -- Note that we trigger on 'UNIT_HEALTH' because that's the easiest way to
    -- tell if a unit has revived.  And, once we're listening for
    -- 'UNIT_HEALTH', we don't need a separate trigger to detect unit death.

    if UnitGroupRolesAssigned(unit) ~= "HEALER" then
        return
    end

    if not aura_env.isGroupUnitId(unit) then
        return
    end

    aura_env:cacheHealerState(unit)
    WeakAuras.ScanEvents("WA_HEALERWATCH_UPDATE", event, unit)
end

-- trigger4: CHAT_MSG_ADDON
function(event, prefix, message, channel, sender)
    -- Note that 'sender' seems always to include the realm name.

    if prefix ~= "HealerWatch_WA"
    or sender == aura_env.playerNameWithRealm then
        return
    end

    if channel ~= "PARTY"
    and channel ~= "RAID"
    and channel ~= "INSTANCE_CHAT" then
        return
    end

    local unit = aura_env.getHealerUnitIdFromName(sender)
    if unit == nil then
        return
    end

    -- As an extra precaution against message lag, drop this event if 'unit' is
    -- dead or if we can query for 'unit's mana ourselves.

    if UnitIsDeadOrGhost(unit)
    or Enum.PowerType.Mana == UnitPowerType(unit) then
        return
    end

    aura_env.healerMana[UnitGUID(unit)] = tonumber(message)
    WeakAuras.ScanEvents("WA_HEALERWATCH_UPDATE", event, sender)
end

-- trigger5: WA_HEALERWATCH_UPDATE
function(_, ...)
    -- TODO: Account for range if the player is in a battleground.

    -- print(...)

    local manaSum = 0

    for _, mana in pairs(aura_env.healerMana) do
        manaSum = manaSum + mana
    end

    if manaSum == 0 then
        aura_env.manaAverage = 0
    else
        aura_env.manaAverage = manaSum / aura_env.numHealers
    end

    return true
end

-- untrigger
function()
    return false
end

-- duration
function()
    return aura_env.manaAverage, 100, true
end

-- overlay
function()
    if aura_env.numHealers == nil or aura_env.numHealers == 0 then
        return 0, 100
    end

    return 100 - ((aura_env.numDeadHealers / aura_env.numHealers) * 100), 100
end

--[[ TODO
        - enable range detection in battlegrounds
        - is 'UNIT_POWER_FREQUENT' worth the performance cost?
        - would it be more efficient or otherwise better to retrieve mana values on each valid update event?
]]

-- init
C_ChatInfo.RegisterAddonMessagePrefix("HealerWatch_WA")
aura_env.playerNameWithRealm = GetUnitName("player") .. '-' .. GetRealmName()

function aura_env.resetRoster(self)
    -- Reset the 'aura_env' state.

    -- A dictionary that maps from healer unit ID to a mana value.  The unit
    -- IDs are strictly limited to those returned by 'WA_IterateGroupMembers'.
    self.healerMana = {}

    -- The number of entries in 'self.healerMana'.
    self.numHealers = 0

    -- A set of unit IDs for dead healers in the group.  The set of unit IDs is
    -- strictly a subset of those in 'self.healerMana'.
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

    if UnitIsDeadOrGhost(unit) then
        self.healerMana[unit] = 0

        if self.deadHealers[unit] == nil then
            self.deadHealers[unit] = true
            self.numDeadHealers = self.numDeadHealers + 1
        end
    else
        if self.canAccessUnitMana(unit) then
            local mana = (100 * UnitPower(unit, Enum.PowerType.Mana)
                              / UnitPowerMax(unit, Enum.PowerType.Mana))

            self.healerMana[unit] = mana
        end

        if self.deadHealers[unit] ~= nil then
            self.deadHealers[unit] = nil
            self.numDeadHealers = aura_env.numDeadHealers - 1
        end
    end
end

function aura_env.canAccessUnitMana(unit)
    -- Return 'true' if we can query for 'unit's mana.  Otherwise, return
    -- 'false'.

    return Enum.PowerType.Mana == UnitPowerType(unit) or unit == "player"
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
            --
            -- This also guarantees that 'unit' is registered as a healer,
            -- which must be done for lookups done by other event handlers.
            -- (In other words, the implementation could change the default
            -- mana value, but the mana value must not be 'nil'.)

            aura_env.healerMana[unit] = 100

            aura_env:cacheHealerState(unit)
        end
    end

    WeakAuras.ScanEvents("WA_HEALERWATCH_UPDATE", event)
end

-- trigger2: UNIT_POWER_UPDATE
function(event, unit)
    if aura_env.healerMana[unit] == nil
    or not aura_env.canAccessUnitMana(unit) then
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

    if aura_env.healerMana[unit] == nil then
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

    -- Check if 'sender' is the name of a unit in 'aura_env.healerMana'.

    local unit
    for healerUnit, _ in pairs(self.healerMana) do
        local name, realm = UnitName(healerUnit)

        if realm == nil then
            realm = GetRealmName()
        end

        if (name .. "-" .. realm) == fullUnitName then
            unit = healerUnit
            break
        end
    end

    if unit == nil then
        -- 'sender' is not the name of a unit in 'aura_env.healerMana'.  Drop
        -- this event.

        return
    end

    -- As an extra precaution against message lag, drop this event if 'unit' is
    -- dead or if we can query for 'unit's mana ourselves.

    if UnitIsDeadOrGhost(unit)
    or aura_env.canAccessUnitMana(unit) then
        return
    end

    aura_env.healerMana[unit] = tonumber(message)
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

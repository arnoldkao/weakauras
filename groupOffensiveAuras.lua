--[[
Maybe TODO:
    - Clear all states all group members leave combat
    - Trigger off of CLEU rather than UNIT_AURA to avoid nameplate shenanigans
]]--

-------------------------------------------------------------------------------
-- init

-- "Default" tracked auras, as a map from spell ID to a non-'nil' value.

aura_env.spells = {
    -- Covenant Abilities
    -- Notably missing:
    --  - The Hunt (Demon Hunter, Night Fae)
    --  - Mirrors of Torment (Mage, Venthyr)
    --  - Faeline Stomp (Monk, Night Fae)
    [317009] = true,    -- Sinful Brand (Demon Hunter, Venthyr)

    -- Monk
    [123725] = true,    -- Breath of Fire
    [325153] = true,    -- Exploding Keg

    -- Demon Hunter
    [207771] = true,    -- Fiery Brand

    -- Warrior
    [1160] = true,      -- Demoralizing Shout
    [275335] = true,    -- Punish

    -- Druid
    [80313] = true,     -- Pulverize
    [135601] = true,    -- Tooth and Claw

    -- Death Knight
    [206931] = true,    -- Booddrinker
}

-- Selectively enable/disable the defaults and the spells added in Custom
-- Options.

if not aura_env.config.enableDefaults then
    aura_env.spells = {}
end

if aura_env.config.enableAdded then
    for _,spellOption in ipairs(aura_env.config.addedSpells) do
        if spellOption.spellId ~= 0 then
            aura_env.spells[spellOption.spellId] = true
        end
    end
end

local AuraTimerMixin = {
    SetDuration = function(self, value)
        self.duration = value
    end,

    SetExpirationTime = function(self, value)
        self.expirationTime = value
    end,

    GetDuration = function(self)
        return self.duration
    end,

    GetExpirationTime = function(self)
        return self.expirationTime
    end
}

aura_env.createAuraTimer = function(duration, expirationTime)
    local auraTimer = CreateFromMixins(AuraTimerMixin)
    auraTimer:SetDuration(duration)
    auraTimer:SetExpirationTime(expirationTime)

    return auraTimer
end

aura_env.getTargetsSummary = function(targets)
    -- Iterate through the specified 'targets' to return the number of entries
    -- whose expiration time is not yet past and the 'AuraTimer' object with
    -- the max expiration time.  If 'targets' is empty, return 0 and 'nil'
    -- instead.  'targets' must be a map from a unit identifier (e.g., unit
    -- GUID) to an 'AuraTimerMixin' object for a particular spell on that unit.

    local count = 0
    local maxAuraTimer = nil

    local currentTime = GetTime()

    for unitGuid, auraTimer in pairs(targets) do
        if auraTimer:GetExpirationTime() <= currentTime then
            -- Delete this entry from 'targets' for cleanliness.

            targets[unitGuid] = nil
        else
            count = count + 1
            if maxAuraTimer == nil
            or auraTimer:GetExpirationTime() > maxAuraTimer:GetExpirationTime()
                                                                           then
                maxAuraTimer = auraTimer
            end
        end
    end

    return count, maxAuraTimer
end

-------------------------------------------------------------------------------
-- TSU: UNIT_AURA:nameplate, NAME_PLATE_UNIT_ADDED, CLEU:UNIT_DIED

function(allstates, event, ...)
    -- Keep track of what the return value should be and of what spell IDs
    -- we've found for this event.

    local changed = false
    local seenSpellIds = {}

    local targetGuid = nil

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Get the dead unit's GUID and skip ahead to remove it from all
        -- states' target lists.

        targetGuid = select(8, CombatLogGetCurrentEventInfo())
    else
        -- Ignore events for nil and friendly units.

        local unit = ...
        if unit == nil or UnitIsFriend("player", unit) then
            return false
        end

        targetGuid = UnitGUID(unit)

        -- Iterate through all debuffs on this unit.

        for i = 1, 40 do
            local _, icon, _, _, duration, expirationTime, sourceUnit, _, _, spellId = UnitDebuff(unit, i)

            if spellId == nil then
                break
            end

            if (UnitInParty(sourceUnit) or UnitInRaid(sourceUnit))
            and aura_env.spells[spellId] ~= nil then
                -- This spell is tracked, and it's applied by a unit in our
                -- group.  Ensure that there is an entry in 'allstates' for
                -- this spell from this group member.

                local stateId = UnitGUID(sourceUnit) .. spellId
                seenSpellIds[spellId] = true

                local state = allstates[stateId]

                if state == nil then
                    state = {}
                    allstates[stateId] = state

                    changed = true

                    state.changed = true
                    state.show = true
                    state.unit = sourceUnit
                    state.icon = icon
                    state.spellId = spellId
                    state.progressType = "timed"
                    state.autoHide = true
                    state.duration = duration
                    state.expirationTime = expirationTime

                    state.targetCount = 1

                    -- Maintain information about this spell from this group
                    -- member on this particular target.

                    state.targets = {}
                    state.targets[targetGuid] = aura_env.createAuraTimer(duration, expirationTime)
                else
                    state.targets[targetGuid] = aura_env.createAuraTimer(duration, expirationTime)

                    local targetCount, maxAuraTimer = aura_env.getTargetsSummary(state.targets)

                    if targetCount == 0 then
                        -- Hide the display.  Note that this condition might
                        -- occur if 'expirationTime' has already passed.

                        changed = true

                        state.changed = true
                        state.show = false
                    elseif state.targetCount ~= targetCount
                    or state.duration ~= maxAuraTimer:GetDuration()
                    or state.expirationTime ~= maxAuraTimer:GetExpirationTime() then
                        -- Update the display.

                        changed = true

                        state.changed = true
                        state.duration = maxAuraTimer:GetDuration()
                        state.expirationTime = maxAuraTimer:GetExpirationTime()

                        state.targetCount = targetCount
                    end
                end
            end
        end
    end

    -- Iterate through all states for 'targetGuid'.  If there is a state for a
    -- spell whose target list includes 'targetGuid' but is not in the
    -- 'seenSpellIds' set, delete 'targetGuid' from that state's target list
    -- and decrement its 'targetCount' value.

    for _, state in pairs(allstates) do
        if seenSpellIds[state.spellId] == nil
        and state.targets[targetGuid] ~= nil then
            state.targets[targetGuid] = nil

            local targetCount, maxAuraTimer = aura_env.getTargetsSummary(state.targets)

            changed = true

            state.changed = true

            state.targetCount = targetCount

            if targetCount > 0 then
                state.duration = maxAuraTimer:GetDuration()
                state.expirationTime = maxAuraTimer:GetExpirationTime()
            else
                state.show = false
            end
        end
    end

    return changed
end

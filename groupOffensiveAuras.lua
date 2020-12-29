--[[
Maybe TODO:
    - Clear all states all group members leave combat
    - Trigger off of CLEU rather than UNIT_AURA to avoid nameplate shenanigans
]]--

-------------------------------------------------------------------------------
-- init

-- "Default" tracked auras, as a map from spell ID to a non-'nil' value.

aura_env.spells = {
    [164812] = true,    -- Moonfire

    -- Demon Hunter
    [207771] = true     -- Fiery Brand
}

aura_env.getTargetInfo = function(targets)
    -- Iterate through the specified 'targets' to return the number of entries
    -- whose expiration time is not yet past and the max expiration time.
    -- 'targets' must be a map from a unit identifier (e.g., unit GUID) to the
    -- expiration time (as comparable to 'GetTime()') of a particular spell on
    -- that unit.

    local count = 0
    local maxExpirationTime = 0

    for unitGuid, expirationTime in pairs(targets) do
        if expirationTime <= GetTime() then
            -- Delete this entry from 'targets' for cleanliness.

            targets[unitGuid] = nil
        else
            count = count + 1
            if expirationTime > maxExpirationTime  then
                maxExpirationTime = expirationTime
            end
        end
    end

    return count, maxExpirationTime
end

-------------------------------------------------------------------------------
-- TSU: UNIT_AURA:nameplate

function(allstates, event, unit)
    -- Ignore events for friendly units.

    if UnitIsFriend("player", unit) then
        return false
    end

    local targetGuid = UnitGUID(unit)

    -- Iterate through all debuffs on this unit.  Keep track of what the return
    -- value should be and of what spell IDs we've found for this occurrence of
    -- 'UNIT_AURA' for 'unit'.

    local changed = false
    local seenSpellIds = {}

    for i = 1, 40 do
        local _, icon, _, _, duration, expirationTime, sourceUnit, _, _, spellId = UnitDebuff(unit, i)

        if spellId == nil then
            break
        end

        if (UnitInParty(sourceUnit) or UnitInRaid(sourceUnit))
        and aura_env.spells[spellId] ~= nil then
            -- This spell is tracked, and it's applied by a unit in our group.
            -- Ensure that there is an entry in 'allstates' for this spell from
            -- this group member.

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

                -- Maintain information about this spell from this group member
                -- on this particular target.

                state.targets = {}
                state.targets[targetGuid] = expirationTime
            else
                state.targets[targetGuid] = expirationTime

                local targetCount, maxExpirationTime = aura_env.getTargetInfo(state.targets)

                if state.targetCount ~= targetCount
                or state.expirationTime ~= expirationTime then
                    -- Update the display.

                    changed = true

                    state.changed = true
                    state.expirationTime = maxExpirationTime

                    state.targetCount = targetCount
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

            local targetCount, maxExpirationTime = aura_env.getTargetInfo(state.targets)

            changed = true

            state.changed = true
            state.expirationTime = maxExpirationTime

            state.targetCount = targetCount
        end
    end

    return changed
end

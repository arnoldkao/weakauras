-------------------------------------------------------------------------------
-- init

aura_env.throwingUnits = {} -- A set of unit GUIDs casting "Throw Cleaver".
aura_env.enemyUnits = {}    -- A map from unit GUID to a nameplate unit ID.
aura_env.groupUnits = {}    -- A map from unit GUID to group unit ID.

aura_env.update = function(allstates)
    -- Cross-reference 'aura_env.throwingUnits', 'aura_env.enemyUnits', and
    -- 'aura_env.groupUnits' to update the specified 'allstates'.  Return
    -- 'true' if any states are changed.  Otherwise, return 'false'.

    -- Iterate through 'aura_env.throwingUnits' to put together a map from
    -- group unit GUID to the number of enemies throwing cleaver at him/her.

    local targets = {}

    for throwerGuid, _ in pairs(aura_env.throwingUnits) do
        local throwerId = aura_env.enemyUnits[throwerGuid]
        if throwerId ~= nil then
            local targetGuid = UnitGUID(throwerId .. "target")
            if targetGuid ~= nil then
                targets[targetGuid] = (targets[targetGuid] or 0) + 1
            end
        end
    end

    local changedAny = false

    for targetGuid, numThrowing in pairs(targets) do
        local state = allstates[targetGuid]

        if state == nil then
            if numThrowing > 1 then
                allstates[targetGuid] = {
                    ["stacks"] = numThrowing,
                    ["show"] = true,
                    ["changed"] = true
                }

                changedAny = true
            end
        else
            if state.stacks ~= numThrowing
            or state.show ~= (numThrowing > 1) then
                state.stacks = numThrowing
                state.show = (numThrowing > 1)
                state.changed = true

                changedAny = true
            end
        end
    end

    return changedAny
end

-------------------------------------------------------------------------------
-- trigger (TSU): GROUP_ROSTER_UPDATE, CLEU:SPELL_CAST_START, CLEU:SPELL_CAST_SUCCESS, CLEU:SPELL_CAST_FAILED, NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED

function(allstates, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED"
    or event == "NAME_PLATE_UNIT_REMOVED" then
        local unitId = ...
        if unitId == nil then
            return false
        end

        local unitGuid = UnitGUID(unitId)
        local npcId = select(6, strsplit("-", unitGuid))
        npcId = tonumber(npcId)

        if npcId ~= 173044          -- Stitching Assistant
        and npcId ~= 167731         -- Separation Assistant
        and npcId ~= 165872 then    -- Flesh Crafter
            return false
        end

        -- Map from this unit's GUID to the unit ID.

        aura_env.enemyUnits[unitGuid] = unitId
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, casterGuid = ...
        local spellId = select(12, ...)

        if spellId ~= 323496 then
            return false
        end

        -- Record this unit GUID as casting or not casting "Throw Cleaver".

        if subevent == "SPELL_CAST_START" then
            aura_env.throwingUnits[casterGuid] = true
        else    -- subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED"
            aura_env.throwingUnits[casterGuid] = nil
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Update the lookup map from unit GUID to group unit ID.

        local groupUnits = {}
        for unit in WA_IterateGroupMembers() do
            groupUnits[UnitGUID(unit)] = unit
        end
        aura_env.groupUnits = groupUnits
    end

    return aura_env.update(allstates)
end

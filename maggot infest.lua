-- Show an icon over the nameplates of maggots that are engaged in combat and
-- have not yet been interrupted while casting infest.

-- init
aura_env.maggotsPending = {}

aura_env.npcId = 134024
aura_env.spellId = 278444
aura_env.icon = select(3, GetSpellInfo(aura_env.spellId))

-- trigger: UNIT_THREAT_LIST_UPDATE, UNIT_SPELLCAST_INTERRUPTED, PLAYER_REGEN_ENABLED
function(allstates, event, unit, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        -- The player has exited combat.  Clear the set of maggots and change
        -- all states in 'allstates' to be hidden.

        aura_env.maggotsPending = {}

        local changedAny = false
        for _,v in pairs(allstates) do
            if v.show == true then
                v.changed = true
                v.show = false
                changedAny = true
            end
        end

        return changedAny
    end

    if unit == nil then
        return false
    end

    local unitGuid = UnitGUID(unit)
    if unitGuid == nil then
        return false
    end

    if event == "UNIT_THREAT_LIST_UPDATE" then
        local npcId = select(6, strsplit("-", unitGuid))
        npcId = tonumber(npcId)
        if npcId ~= aura_env.npcId then
            return false
        end

        if select(10, UnitBuff(unit, 1)) ~= 278431 then
            -- This maggot is not parasitic.  Do not track it.

            return false
        end

        if UnitThreatSituation("player", unit) ~= nil then
            -- This maggot is engaged in combat with the player.

            if aura_env.maggotsPending[unitGuid] ~= nil then
                -- This maggot is already in the set of tracked maggots.

                return false
            end

            -- This maggot is not already in the set of maggots pending a
            -- cast.  Add it and show a state for it.

            aura_env.maggotsPending[unitGuid] = true

            local state = {}
            allstates[unitGuid] = state

            state.changed = true
            state.show = true
            state.icon = aura_env.icon
            state.unit = unit

            return true
        else
            -- This unit no longer has the player on its threat table.  Remove
            -- it from the set of maggots pending a cast and hide the state
            -- for it.

            aura_env.maggotsPending[unitGuid] = nil

            local state = allstates[unitGuid]
            if state == nil then
                return false
            end

            state.changed = true
            state.show = false

            return true
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local spellId = select(2, ...)
        if spellId ~= aura_env.spellId then
            return false
        end

        -- The unit was interrupted while casting infest.  Mark it as having
        -- failed its cast in the set of maggots pending a cast and hide the
        -- state for it.  Note that we have to keep the unit's entry in the
        -- set so that it isn't re-added and marked as pending when its threat
        -- table is updated.

        aura_env.maggotsPending[unitGuid] = false

        local state = allstates[unitGuid]
        if state == nil then
            return false
        end

        state.changed = true
        state.show = false

        return true
    end
end
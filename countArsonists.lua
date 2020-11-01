-- init
aura_env.npcMatches = {}

-- trigger: UNIT_THREAT_LIST_UPDATE, PLAYER_REGEN_ENABLED
function(event, unit)
    if event == "UNIT_THREAT_LIST_UPDATE" then
        local unitGuid = UnitGUID(unit)
        if unitGuid ~= nil then
            local npcId = select(6, strsplit("-", unitGuid))
            npcId = tonumber(npcId)
            if npcId == aura_env.config.npcId then
                if UnitThreatSituation("player", unit) ~= nil then
                    aura_env.npcMatches[unitGuid] = true
                else
                    -- Player is no longer on this unit's threat table (i.e.,
                    -- the unit died, the unit reset, or player dropped combat).

                    aura_env.npcMatches[unitGuid] = nil
                end
            end
        end

        local count = 0
        for _,_ in pairs(aura_env.npcMatches) do
            count = count + 1
        end

        aura_env.numNpcMatches = count
        return count ~= 0
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- The player is no longer in combat.  Clear the set of NPC matches,
        -- in case the 'UNIT_THREAT_LIST_UPDATE' event does not fire for all
        -- units (e.g., if the unit died while their nameplate wasn't visible
        -- on the player's screen).

        aura_env.npcMatches = {}
        return false
    end
end

-- untrigger
function(event)
    return true
end

-- stacks
function()
    return aura_env.numNpcMatches
end

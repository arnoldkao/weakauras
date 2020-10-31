-- init
aura_env.lieutenantConstants = {
    [161243] = { "Samh'rek, Beckoner of Chaos", aura_env.config.nicknames.fear },
    [161124] = { "Urg'roth, Breaker of Heroes", aura_env.config.nicknames.tankBuster },
    [161241] = { "Voidweaver Mal'thir", aura_env.config.nicknames.spider },
    [161244] = { "Blood of the Corruptor", aura_env.config.nicknames.blob }
}

aura_env.colorizeText = function(colorArray, text)
    local color = CreateColor(colorArray[1], colorArray[2], colorArray[3], colorArray[4])
    return color:WrapTextInColorCode(text)
end

aura_env.initializeState = function()
    aura_env.lieutenantsKilled = {}
    for k,v in pairs(aura_env.lieutenantConstants) do
        aura_env.lieutenantsKilled[k] = false
    end
end

local MDT = MDT or MethodDungeonTools
aura_env.calculateObeliskForces = function()
    if (MDT ~= nil
    and MDT.GetEnemyForces ~= nil
    and MDT.IsWeekTeeming ~= nil) then
        local count, maxCount, maxCountTeeming, teemingCount = MDT:GetEnemyForces(161244)
        if MDT:IsWeekTeeming() then
            count = teemingCount
            maxCount = maxCountTeeming
        end

        local forces = ""
        if aura_env.config.showCount then
            forces = forces .. count
        end
        if aura_env.config.showPercent then
            if forces ~= "" then
                forces = forces .. " "
            end
            forces = forces .. "(" .. string.format("%.2f%%", count / maxCount * 100) .. ")"
        end

        aura_env.forces = forces
    end
end

aura_env.initializeState()

-- trigger: CHALLENGE_MODE_START, UNIT_HEALTH, PLAYER_ENTERING_WORLD, WA_DEFERRED_OBELISK_FORCES
function(event, ...)
    if event == "CHALLENGE_MODE_START" then
        -- This event is fired both on key start and upon rezoning into an
        -- active keystone dungeon.

        aura_env.initializeState()

        -- This timer is required to work around MDT observing that we're not
        -- yet in an instance and thus defaulting to returning the forces for
        -- obelisks in Atal'Dazar.

        C_Timer.After(1, function() WeakAuras.ScanEvents("WA_DEFERRED_OBELISK_FORCES") end)
    elseif event == "UNIT_HEALTH" then
        local unit = select(1, ...)
        local unitGuid = UnitGUID(unit)
        if unitGuid ~= nil then
            local npcId = select(6, strsplit("-", unitGuid))
            if npcId ~= nil then
                npcId = tonumber(npcId)
                -- TODO: add a condition below so that if the lieutenant was
                -- pulled with the last boss, the lieutenant is considered dead
                -- only if both it and the boss are dead.

                if UnitIsDead(unit) and aura_env.lieutenantsKilled[npcId] ~= nil then
                    aura_env.lieutenantsKilled[npcId] = true
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Note that this event is fired only on UI reload and not upon zoning
        -- into the instance, presumably because the aura loads only after this
        -- event is fired.

        aura_env.calculateObeliskForces()
    elseif event == "WA_DEFERRED_OBELISK_FORCES" then
        aura_env.calculateObeliskForces()
    end

    -- always enable, as long as the weakaura is loaded
    return true
end

-- untrigger
function()
    return false
end

-- name
function()
    local statusText = ""
    for k,v in pairs(aura_env.lieutenantsKilled) do
        if v ~= nil then
            local lieutenantName = aura_env.lieutenantConstants[k][2]
            if lieutenantName == "" then
                lieutenantName = aura_env.lieutenantConstants[k][1]
            end

            local line = nil
            if v then
                line = aura_env.colorizeText(aura_env.config.colors.complete, lieutenantName .. ": 1/1\n")
            else
                line = aura_env.colorizeText(aura_env.config.colors.incomplete, lieutenantName .. ": 0/1\n")
            end

            statusText = statusText .. line
        end
    end

    if aura_env.forces ~= nil then
        statusText = statusText .. "\n" .. aura_env.colorizeText(aura_env.config.colors.forces, aura_env.forces)
    end

    return statusText
end
-- init
aura_env.customNames = {
    [375] = aura_env.config.mists,
    [376] = aura_env.config.wake,
    [377] = aura_env.config.side,
    [378] = aura_env.config.halls,
    [379] = aura_env.config.plague,
    [380] = aura_env.config.depths,
    [381] = aura_env.config.spires,
    [382] = aura_env.config.theater
}

-- trigger: BAG_UPDATE_DELAYED, CHALLENGE_MODE_START, CHALLENGE_MODE_COMPLETED, WA_DEFERRED_KEYSTONE_CHECK
function(event)
    if event == "CHALLENGE_MODE_COMPLETED" then
        -- The keystone changes after this event is fired. Schedule an update.

        C_Timer.After(1, function() WeakAuras.ScanEvents("WA_DEFERRED_KEYSTONE_CHECK") end)
        return false
    else
        aura_env.keystoneMapId = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        return aura_env.keystoneMapId ~= nil
    end
end

-- untrigger
function()
    return aura_env.keystoneMapId == nil
end

-- name
function()
    local name = aura_env.customNames[aura_env.keystoneMapId]
    if name == "" then
        name = C_ChallengeMode.GetMapUIInfo(aura_env.keystoneMapId)
    end

    return name .. " (" .. C_MythicPlus.GetOwnedKeystoneLevel() .. ")"
end

-- icon
function()
    return select(4, C_ChallengeMode.GetMapUIInfo(aura_env.keystoneMapId))
end

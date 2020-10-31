--[[
TODO:
]]

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
    return C_ChallengeMode.GetMapUIInfo(aura_env.keystoneMapId) .. " (" .. C_MythicPlus.GetOwnedKeystoneLevel() .. ")"
end

-- icon
function()
    return select(4, C_ChallengeMode.GetMapUIInfo(aura_env.keystoneMapId))
end
-- init
WeakAuras.WatchSpellCooldown(210152)

aura_env.canFitOneMoreDeathSweep = function()
    -- Return 'true' if death sweep will come off cooldown right before meta
    -- expires.  Otherwise, return 'false'.

    local metaExpirationTime = aura_env.metaExpirationTime
    local deathSweepReadyTime = aura_env.deathSweepReadyTime

    return (metaExpirationTime and deathSweepReadyTime
        and metaExpirationTime - 2 < deathSweepReadyTime
        and deathSweepReadyTime < metaExpirationTime - 0.1)    -- Add a tolerance of 100ms
end

-- trigger: SPELL_COOLDOWN_CHANGED:210152, UNIT_AURA:player
function(event, arg1)
    if event == "SPELL_COOLDOWN_CHANGED" and arg1 == 210152 and aura_env.metaExpirationTime ~= nil then
        local start, duration = GetSpellCooldown(210152)
        if start ~= 0 then
            aura_env.deathSweepReadyTime = start + duration
        else
            aura_env.deathSweepReadyTime = nil
        end
    elseif event == "UNIT_AURA" then
        local _, _, _, _, _, expirationTime = WA_GetUnitBuff("player", 162264)
        aura_env.metaExpirationTime = expirationTime
    end

    return aura_env.canFitOneMoreDeathSweep()
end

-- untrigger
function(event)
    return true
end
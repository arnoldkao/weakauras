-------------------------------------------------------------------------------
-- trigger: UNIT_AURA:player,
--          UNIT_SPELLCAST_START:player,
--          UNIT_SPELLCAST_DELAYED:player,
--          UNIT_SPELLCAST_STOP:player,
--          UNIT_SPELLCAST_CHANNEL_START:player,
--          UNIT_SPELLCAST_CHANNEL_UPDATE:player,
--          UNIT_SPELLCAST_CHANNEL_STOP:player,
--          UNIT_SPELLCAST_INTERRUPTIBLE:player,
--          UNIT_SPELLCAST_NOT_INTERRUPTIBLE:player,
--          UNIT_SPELLCAST_INTERRUPTED:player

function(event, ...)
    if event == "UNIT_AURA" then
        aura_env.quakingDuration, aura_env.quakingExpirationTime = select(5, WA_GetUnitDebuff("player", 240447))
    else    -- event:match("UNIT_SPELLCAST_")
        local castExpirationTime, _, _, notInterruptible = select(5, UnitCastingInfo("player"))
        if castExpirationTime == nil then
            castExpirationTime, _, notInterruptible = select(5, UnitChannelInfo("player"))
        end

        if castExpirationTime ~= nil and not notInterruptible then
            aura_env.castExpirationTime = castExpirationTime / 1000
        else
            aura_env.castExpirationTime = nil
        end
    end

    return aura_env.quakingExpirationTime ~= nil
        and aura_env.castExpirationTime ~= nil
        and aura_env.quakingExpirationTime < aura_env.castExpirationTime
end

-------------------------------------------------------------------------------
-- untrigger

function()
    return true
end

-------------------------------------------------------------------------------
-- duration

function()
    return aura_env.quakingDuration, aura_env.quakingExpirationTime
end

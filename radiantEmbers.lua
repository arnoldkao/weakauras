-------------------------------------------------------------------------------
-- init

WeakAuras.WatchSpellCooldown(316958)

local singleState = {
    ["progressType"] = "timed",
    ["autoHide"] = false,
    ["spellId"] = 316958,

    ["cooldownExpiration"] = 0,
    ["wearingRadiantEmbers"] = WeakAuras.CheckForItemBonusId(7701),
}
aura_env.singleState = singleState

aura_env.getState = function(allstates)
    -- Insert 'singleState' into the specified 'allstates' if it is not already
    -- present.  Return 'singleState'.

    local state = allstates[1]
    if state == nil then
        allstates[1] = singleState
    end

    return singleState
end

aura_env.cancelExpirationTimer = function()
    local timerHandle = singleState.ashenHallowExpirationHandle
    if timerHandle ~= nil then
        timerHandle:Cancel()
    end
end

-------------------------------------------------------------------------------
-- trigger (TSU): PLAYER_EQUIPMENT_CHANGED, CLEU:SPELL_CAST_SUCCESS, SPELL_COOLDOWN_CHANGED, SPELL_COOLDOWN_READY, WA_RADIANTEMBERS_ASHENHALLOWEXPIRED, WA_RADIANTEMBERS_DUMMY

function(allstates, event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local state = aura_env.getState(allstates)

        local wasWearingRadiantEmbers = state.wearingRadiantEmbers
        local isWearingRadiantEmbers = WeakAuras.CheckForItemBonusId(7701)

        if wasWearingRadiantEmbers ~= isWearingRadiantEmbers then
            state.wearingRadiantEmbers = isWearingRadiantEmbers

            state.changed = true
            return true
        else
            return false
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local sourceGuid = select(4, ...)
        local spellId = select(12, ...)

        if sourceGuid ~= UnitGUID("player") or spellId ~= 316958 then
            return false
        end

        local state = aura_env.getState(allstates)

        local duration = state.wearingRadiantEmbers and 45 or 30
        state.expirationTime = GetTime() + duration
        state.duration = duration
        state.ashenHallowOnCooldown = true
        state.ashenHallowActive = true

        aura_env.cancelExpirationTimer()

        state.ashenHallowExpirationHandle = C_Timer.NewTimer(
            duration,
            function()
                WeakAuras.ScanEvents("WA_RADIANTEMBERS_ASHENHALLOWEXPIRED")
            end)

        state.changed = true
        return true
    elseif event == "SPELL_COOLDOWN_CHANGED" then
        local spellId = ...

        if spellId ~= 316958 then
            return false
        end

        local state = aura_env.getState(allstates)

        local newCooldownStart, newCooldownDuration = GetSpellCooldown(316958)
        local newCooldownExpiration = newCooldownStart + newCooldownDuration

        local cooldownReduced = (newCooldownExpiration
                                                    < state.cooldownExpiration)

        state.cooldownExpiration = newCooldownExpiration
        state.cooldownDuration = newCooldownDuration

        if cooldownReduced then
            aura_env.cancelExpirationTimer()

            state.expirationTime = newCooldownExpiration
            state.duration = newCooldownDuration

            state.ashenHallowActive = false

            state.changed = true
            return true
        end

        return false
    elseif event == "WA_RADIANTEMBERS_ASHENHALLOWEXPIRED" then
        local state = aura_env.getState(allstates)

        local cooldownStart, cooldownDuration = GetSpellCooldown(316958)

        state.expirationTime = cooldownStart + cooldownDuration
        state.duration = cooldownDuration
        state.ashenHallowActive = false

        state.changed = true
        return true
    elseif event == "SPELL_COOLDOWN_READY" then
        local spellId = ...

        if spellId ~= 316958 then
            return false
        end

        aura_env.cancelExpirationTimer()

        local state = aura_env.getState(allstates)

        state.expirationTime = nil
        state.duration = nil
        state.ashenHallowOnCooldown = false

        state.changed = true
        return true
    elseif event == "WA_RADIANTEMBERS_DUMMY" then
        local state = aura_env.getState(allstates)

        local cooldownStart, cooldownDuration = GetSpellCooldown(316958)

        state.expirationTime = cooldownStart + cooldownDuration
        state.duration = cooldownDuration

        state.ashenHallowOnCooldown = (cooldownStart ~= 0)
        state.ashenHallowActive = false

        state.show = true
        state.changed = true
        return true
    end
end

-------------------------------------------------------------------------------
-- custom variables

{
    ["expirationTime"] = true,
    ["duration"] = true,

    ["wearingRadiantEmbers"] = "bool",
    ["ashenHallowOnCooldown"] = "bool",
    ["ashenHallowActive"] = "bool",
}

--[[ Testing 5/20

- cast with lego equipped, then unequip lego
    - ashen has 45 sec duration
    - running out doesn't give CDR or clear ashen
- cast with lego unequipped, then equip lego
    - ashen has 30 sec duration
    - running out gives CDR and clears ashen

-- does ashen hallow clear on raid boss reset?
]]

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
    -- Cancel the scheduled event that signals that Ashen Hallow expired.

    local timerHandle = singleState.ashenHallowExpirationHandle
    if timerHandle ~= nil then
        timerHandle:Cancel()
    end
end

aura_env.setShow = function()
    -- Set the 'singleState.show' value to 'true' or 'false' depending on
    -- 'singleState.ashenHallowActive' and 'aura_env.config.showWhen'.

    local state = singleState
    local showWhen = aura_env.config.showWhen

    if showWhen == 1 then       -- Always
        state.show = true
    elseif showWhen == 2 then   -- Only when active
        state.show = state.ashenHallowActive
    end
end

-------------------------------------------------------------------------------
-- trigger (TSU): PLAYER_EQUIPMENT_CHANGED, CLEU:SPELL_CAST_SUCCESS, SPELL_COOLDOWN_CHANGED, SPELL_COOLDOWN_READY, WA_RADIANTEMBERS_ASHENHALLOWEXPIRED, WA_RADIANTEMBERS_DUMMY

function(allstates, event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Check whether the player has newly equipped or unequipped Radiant
        -- Embers.

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

        -- The player has casted Ashen Hallow.  Update the progress and state
        -- information, and set a timer to update the progress and state
        -- information again to reflect that Ashen Hallow expired.

        local state = aura_env.getState(allstates)

        local duration = state.wearingRadiantEmbers and 45 or 30
        state.expirationTime = GetTime() + duration
        state.duration = duration
        state.ashenHallowOnCooldown = true
        state.ashenHallowActive = true

        aura_env.setShow()

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

        -- Update the display only if the cooldown was reduced, which we take
        -- as a signal that Ashen Hallow has been deactivated.

        if cooldownReduced then
            aura_env.cancelExpirationTimer()

            state.expirationTime = newCooldownExpiration
            state.duration = newCooldownDuration

            state.ashenHallowActive = false

            aura_env.setShow()

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

        aura_env.setShow()

        state.changed = true
        return true
    elseif event == "SPELL_COOLDOWN_READY" then
        local spellId = ...

        if spellId ~= 316958 then
            return false
        end

        -- Assume that if the cooldown was reset, then the previously placed
        -- Ashen Hallow has disappeared.

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

        -- For simplicity, assume that Ashen Hallow is not active.

        state.ashenHallowOnCooldown = (cooldownStart ~= 0)
        state.ashenHallowActive = false

        aura_env.setShow()

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

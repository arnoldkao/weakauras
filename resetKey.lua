-- trigger: CHALLENGE_MODE_START, PLAYER_ENTERING_WORLD
function(event, ...)
    if event == "CHALLENGE_MODE_START" then
        aura_env.challengeModeStarted = true
        return false
    end

    if event == "PLAYER_ENTERING_WORLD"
    and aura_env.challengeModeStarted then
        local isInitialLogin, isReloadingUi = ...
        if not isInitialLogin and not isReloadingUi then
            aura_env.challengeModeStarted = false
            return true
        end
    end

    return false
end

-- trigger: CLEU
function(event, ...)
    if aura_env.config.filterForPlayer then
        local sourceGuid = select(4, ...)
        local targetGuid = select(8, ...)
        local playerGuid = UnitGUID("player")
        if playerGuid ~= targetGuid and playerGuid ~= sourceGuid then
            return
        end
    end

    print(CombatLogGetCurrentEventInfo())
end

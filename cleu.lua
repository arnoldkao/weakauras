-- trigger (status): CLEU, GROUP_ROSTER_UPDATE
function(event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        local groupUnitGuids = {}
        aura_env.groupUnitGuids = groupUnitGuids
        for unit in WA_IterateGroupMembers() do
            groupUnitGuids[UnitGUID(unit)] = true
        end
    else
        if aura_env.config.unitFilter == 2 then
            local sourceGuid = select(4, ...)
            local targetGuid = select(8, ...)
            local playerGuid = UnitGUID("player")
            if playerGuid ~= targetGuid and playerGuid ~= sourceGuid then
                return
            end
        elseif aura_env.config.unitFilter == 3 then
            local sourceGuid = select(4, ...)
            local targetGuid = select(8, ...)

            local groupUnitGuids = aura_env.groupUnitGuids

            if groupUnitGuids == nil
            or (groupUnitGuids[sourceGuid] == nil
                and groupUnitGuids[targetGuid] == nil) then
                return
            end
        end

        print(CombatLogGetCurrentEventInfo())
    end
end

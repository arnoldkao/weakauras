-------------------------------------------------------------------------------
-- init

-- A map from unit GUID to group unit ID.

aura_env.groupUnits = {}

-- A map from spell target GUIDs to their states.  These states are always
-- inserted into the TSU's 'allstates' table, but we keep an extra reference
-- here so that the states are not deleted when their 'show' values are 'false'
-- (because we want to show the clone only if the 'stacks' value is greater
-- than 1).

aura_env.allstates = {}

-------------------------------------------------------------------------------
-- trigger (TSU): UNIT_SPELLCAST_START, UNIT_SPELLCAST_STOP, GROUP_ROSTER_UPDATE

function(allstates, event, ...)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" then
        local casterUnit, _, spellId = ...

        -- if spellId ~= 323496 then
        if spellId ~= 8936 then
            return false
        end

        if not UnitExists(casterUnit .. "target") then
            return false
        end

        local casterGuid = UnitGUID(casterUnit)
        local targetGuid = UnitGUID(casterUnit .. "target")

        local state = aura_env.allstates[targetGuid]
        if state == nil then
            state = {
                ["stacks"] = 0,
                ["casterGuids"] = {}
            }
            aura_env.allstates[targetGuid] = state
        end

        state.unit = aura_env.groupUnits[targetGuid]

        if event == "UNIT_SPELLCAST_START" then
            if state.casterGuids[casterGuid] == nil then
                state.stacks = state.stacks + 1
                state.casterGuids[casterGuid] = true

                state.changed = true
            end
        else    -- event == "UNIT_SPELLCAST_STOP"
            if state.casterGuids[casterGuid] ~= nil then
                state.stacks = state.stacks - 1
                state.casterGuids[casterGuid] = nil

                state.changed = true

                if state.stacks == 0 then
                    aura_env.allstates[targetGuid] = nil
                end
            end
        end

        state.show = (state.stacks > 1)
        allstates[targetGuid] = state

        print(targetGuid, spellId, state.stacks)

        return state.changed
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Update the lookup map from unit GUID to group unit ID.

        local groupUnits = {}
        for unit in WA_IterateGroupMembers() do
            groupUnits[UnitGUID(unit)] = unit
        end
        aura_env.groupUnits = groupUnits

        -- Iterate through each existing state in 'allstates' to update its
        -- 'unit' value.

        for unitGuid, state in pairs(allstates) do
            state.unit = groupUnits[unitGuid]
            state.changed = true
        end

        return true
    end
end

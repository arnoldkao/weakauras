--[[
This aura tracks the death and revival of group members.
]]

-------------------------------------------------------------------------------
-- init

aura_env.groupMembers = {}

aura_env.makeDeadState = function(unit)
    local state = {
        ["changed"] = true,
        ["show"] = true,
        ["unit"] = unit,
        ["dead"] = true,
    }

    return state
end

-------------------------------------------------------------------------------
-- TSU: GROUP_ROSTER_UPDATE, UNIT_HEALTH

function(allstates, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Hide all states in 'allstates'.

        for _, state in pairs(allstates) do
            state.changed = true
            state.show = false
        end

        -- Iterate through the group to calculate the set of valid group unit
        -- IDs and to insert a state in 'allstates' if the unit is dead.

        local groupMembers = {}
        for unit in WA_IterateGroupMembers() do
            groupMembers[unit] = true

            if UnitIsDeadOrGhost(unit) then
                allstates[unit] = aura_env.makeDeadState(unit)
            end
        end

        aura_env.groupMembers = groupMembers

        return true
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if not aura_env.groupMembers[unit] then
            -- 'unit' is not in our group.

            return false
        end

        if UnitIsDeadOrGhost(unit) then
            -- This unit has died.  Insert a state.

            allstates[unit] = aura_env.makeDeadState(unit)

            return true
        else
            local state = allstates[unit]

            if state == nil or not state.dead then
                -- This unit is already marked as alive.

                return false
            end

            -- This unit is newly alive.  Update the state.

            local duration = aura_env.config.duration

            state.dead = false
            state.progressType = "timed"
            state.expirationTime = GetTime() + duration
            state.duration = duration
            state.autoHide = true

            state.changed = true
            return true
        end
    end
end

-------------------------------------------------------------------------------
-- Custom Variables

{
    ["expirationTime"] = true,
    ["duration"] = true,

    ["dead"] = "bool"
}

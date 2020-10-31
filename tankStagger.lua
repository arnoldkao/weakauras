aura_env.staggerDebuffIds = { 124273, 124274, 124275}

aura_env.getPercentage = function(numerator, denominator)
    return string.format("%.1f%%", numerator / denominator * 100)
end

-- trigger: PLAYER_ROLES_ASSIGNED, UNIT_AURA, UNIT_MAXHEALTH
function(event, arg1)
    if event == "PLAYER_ROLES_ASSIGNED" then
        aura_env.tankUnitId = nil
        
        for unit in WA_IterateGroupMembers() do
            if UnitGroupRolesAssigned(unit) == "TANK" then
                aura_env.tankUnitId = unit
                aura_env.staggerPerTick = 0
                aura_env.tankMaxHealth = UnitHealthMax(unit)
                return true
            end
        end

        return false
    elseif event == "UNIT_AURA" then
        if arg1 == nil or aura_env.tankUnitId == nil or not UnitIsUnit(arg1, aura_env.tankUnitId) then
            return false
        end

        for _, debuffId in pairs(aura_env.staggerDebuffIds) do
            local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, value1 = WA_GetUnitDebuff(aura_env.tankUnitId, debuffId)
            if name ~= nil then
                aura_env.staggerPerTick = value1
                return true
            end
        end

        aura_env.staggerPerTick = 0
        return true
    elseif event == "UNIT_MAXHEALTH" then
        if arg1 == nil or aura_env.tankUnitId == nil or not UnitIsUnit(arg1, aura_env.tankUnitId) then
            return false
        end

        aura_env.tankMaxHealth = UnitHealthMax(aura_env.tankUnitId)
        return true
    end
end

-- name
function()
    return aura_env.staggerPerTick
end

-- custom text
function()
    local value = aura_env.staggerPerTick or 0
    if aura_env.config.perSecond then
        value = value * 2
    end

    return AbbreviateNumbers(value), aura_env.getPercentage(value, aura_env.tankMaxHealth or 1)
end
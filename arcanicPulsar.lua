-------------------------------------------------------------------------------
-- trigger (status): UNIT_AURA:player, OPTIONS

function(event, unit)
    for i = 1, 40 do
        local spellId = select(10, UnitBuff("player", i))
        if spellId == nil then
            break
        end

        if spellId == 338825 then
            local tooltipSize = select(3, WeakAuras.GetAuraTooltipInfo("player", i))

            if aura_env.spent ~= tooltipSize or event == "OPTIONS" then
                aura_env.spent = tooltipSize
                return true
            end

            return false
        end
    end

    if aura_env.spent ~= 0 or event == "OPTIONS" then
        aura_env.spent = 0
        return true
    end

    return false
end

-------------------------------------------------------------------------------
-- untrigger

function()
    return false
end

-------------------------------------------------------------------------------
-- duration

function()
    return aura_env.spent, 300, true
end

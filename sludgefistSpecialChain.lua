function()
    for i = 1, 40 do
        local _, _, _, _, _, _, source, _, _, spellId = UnitDebuff("player", i)
        if spellId == nil then
            return false
        end

        if spellId == 335293 or spellId == 342420 or spellId == 342419 then
            for _, configEntry in pairs(aura_env.config.assigned) do
                if UnitName(source) == configEntry.name then
                    aura_env.roleDescription = configEntry.roleDescription
                    return true
                end
            end
        end
    end
end

function()
    if WeakAuras.IsOptionsOpen() and aura_env.config.assigned[1] ~= nil then
        return aura_env.config.assigned[1].roleDescription
    end

    return aura_env.roleDescription
end

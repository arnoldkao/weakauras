-- init

aura_env.buffs = {
    -- A map from spell ID to a numerical weight of how good the buff is.  A
    -- higher weight indicates a better buff.

    [193356] = 3,   -- Broadside
    [193357] = 3,   -- Ruthless Precision
    [193358] = 1,   -- Grand Melee
    [193359] = 2,   -- True Bearing
    [199600] = 1,   -- Buried Treasure
    [199603] = 3    -- Skull and Crossbones
}

-- The minimum sum at which it's okay not to reroll.
aura_env.buffSumThreshold = 3

-- trigger: UNIT_AURA:player

function()
    local sum = 0

    for i=1,40 do
        local spellId = select(10, UnitAura("player", i, "PLAYER|HELPFUL"))
        if spellId == nil then
            break
        end

        local weight = aura_env.buffs[spellId]
        if weight ~= nil then
            sum = sum + weight
            if sum >= aura_env.buffSumThreshold then
                -- Don't reroll.

                return false
            end
        end
    end

    -- Reroll.

    return true
end

-- untrigger

function()
    return true
end

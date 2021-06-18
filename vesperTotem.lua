-------------------------------------------------------------------------------
-- init

local VESPER_MAX_CHARGES = 3;
local VESPER_SPELL_ID = 324386;
local HEAL_TABLE = {
    [1064] = true, -- Chain Heal
    [61295] = true, -- Riptide
    [77472] = true, -- Healing Wave
    [197995] = true, -- Wellspring
    [73920] = true, -- Healing Rain
    [8004] = true, -- Healing Surge
    [73685] = true, -- Unleash Life
    [108280] = true, -- Healing Tide Totem
    [98008] = true, -- Spirit Link Totem
    [207778] = true, -- Downpour
    [320746] = true, -- Surge of Earth
    [5394] = true, -- Healing Stream Totem
}

local DAMAGE_TABLE = {
    [51505] = true, -- Lava Burst
    [188196] = true, -- Lightning Bolt
    [188389] = true, -- Flame Shock
    [188443] = true, -- Chain Lightning
    [117014] = true, -- Elemental Blast
    [320125] = true, -- Echoing Shock
    [192222] = true, -- Liquid Magma Totem
    [191634] = true, -- Stormkeeper
    [210714] = true, -- Icefury
    [51490] = true, -- Thunderstorm
    [61882] = true, -- Earthquake
    [196840] = true, -- Frost Shock
    [187874] = true, -- Crash Lightning
    [17364] = true, -- Stormstrike
    [60103] = true, -- Lava Lash
    [333974] = true, -- Fire Nova
    [196884] = true, -- Feral Lunge
    [197214] = true, -- Sundering
    [188089] = true, -- Earthen Spike
}

aura_env.remainingHealCharges = 0
aura_env.remainingDamageCharges = 0

aura_env.ProcessCast = function(spellId)
    if spellId == VESPER_SPELL_ID then
        aura_env.remainingHealCharges = VESPER_MAX_CHARGES
        aura_env.remainingDamageCharges = VESPER_MAX_CHARGES

        return true
    else
        if HEAL_TABLE[spellId] then
            if aura_env.remainingHealCharges > 0 then
                aura_env.remainingHealCharges = aura_env.remainingHealCharges - 1
                return true
            end
        elseif DAMAGE_TABLE[spellId] then
            if aura_env.remainingDamageCharges > 0 then
                aura_env.remainingDamageCharges = aura_env.remainingDamageCharges - 1
                return true
            end
        end

        return false
    end
end

-------------------------------------------------------------------------------
-- trigger: UNIT_SPELLCAST_SUCCEEDED:player

function(event, unit, lineId, spellId)
    return aura_env.ProcessCast(spellId);
end

-------------------------------------------------------------------------------
-- custom text

function()
    return aura_env.remainingHealCharges, aura_env.remainingDamageCharges;
end

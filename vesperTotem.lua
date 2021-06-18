-------------------------------------------------------------------------------
-- init

aura_env.healingSpells = {
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

aura_env.damageSpells = {
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

-------------------------------------------------------------------------------
-- TSU: UNIT_SPELLCAST_SUCCEEDED:player, PLAYER_TOTEM_UPDATE

function(allstates, event, ...)
    local state = allstates[1]

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellId = select(3, ...)

        if spellId == 324386 then   -- Vesper Totem
            if state == nil then
                state = {}
                allstates[1] = state
            end

            state.show = true
            state.changed = true
            state.progressType = "timed"
            state.autoHide = true
            state.expirationTime = GetTime() + 30
            state.duration = 30

            state.healingCharges = 3
            state.damageCharges = 3

            return true
        elseif state ~= nil and state.show then
            if aura_env.healingSpells[spellId] then
                if state.healingCharges > 0 then
                    state.healingCharges = state.healingCharges - 1
                    state.changed = true
                end
            elseif aura_env.damageSpells[spellId] then
                if state.damageCharges > 0 then
                    state.damageCharges = state.damageCharges - 1
                    state.changed = true
                end
            end

            if state.changed then
                if state.healingCharges == 0 and state.damageCharges == 0 then
                    state.show = false
                end

                return true
            end

            return false
        end
    elseif event == "PLAYER_TOTEM_UPDATE" and state ~= nil and state.show then
        -- Check for "PLAYER_TOTEM_UPDATE" in case the player cancels the
        -- totem.

        local vesperTotemName = GetSpellInfo(324386)

        for i = 1, MAX_TOTEMS do
            local _, totemName = GetTotemInfo(i)
            if totemName == vesperTotemName then
                -- Vesper Totem is still active.  Do nothing.

                return false
            end
        end

        -- Vesper Totem is inactive.  Disable the state.

        state.show = false
        state.changed = true

        return true
    end
end

-------------------------------------------------------------------------------
-- Custom Variables

{
    ["expirationTime"] = true,
    ["duration"] = true,

    ["healingCharges"] = "number",
    ["damageCharges"] = "number",
}

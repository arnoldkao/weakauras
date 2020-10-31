-- TSU trigger: CLEU:SPELL_HEAL
function(allstates, event)
    local subevent = select(2, CombatLogGetCurrentEventInfo())
    if subevent ~= "SPELL_HEAL" then
        return false
    end

    local sourceGuid = select(4, CombatLogGetCurrentEventInfo())
    local unit = nil
    for groupUnit in WA_IterateGroupMembers() do
        if UnitGUID(groupUnit) == sourceGuid then
            unit = groupUnit
            break
        end
    end
    if unit == nil then
        return false
    end

    local spellId = select(12, CombatLogGetCurrentEventInfo())
    if aura_env.potionSpellIds[spellId] == nil then
        return false
    end

    local state = allstates[unit]
    if state == nil then
        state = {}
        allstates[unit] = state
    end
    state.changed = true
    state.show = true
    state.icon = select(3, GetSpellInfo(spellId))
    state.progressType = "timed"
    state.expirationTime = GetTime() + aura_env.config.duration
    state.duration = aura_env.config.duration
    state.autoHide = true
    state.unit = unit

    return true
end

-- init
aura_env.potionSpellIds = {}
for _,v in pairs(aura_env.config.potions) do
    aura_env.potionSpellIds[v.spellId] = true
end
-------------------------------------------------------------------------------
-- init

local watchedSpellIds = {}

for _, v in pairs(aura_env.config.spells) do
    watchedSpellIds[v.spellId] = true
    WeakAuras.WatchSpellCooldown(v.spellId)
end

aura_env.watchedSpellIds = watchedSpellIds

-------------------------------------------------------------------------------
-- trigger (TSU): SPELL_COOLDOWN_READY

function(allstates, event, spellId)
    local watchedSpellIds = aura_env.watchedSpellIds
    local _

    if spellId == nil then
        -- This is a dummy event.  Create a dummy state to sample the
        -- display and animation.

        spellId, _ = next(watchedSpellIds)
    end

    if not watchedSpellIds[spellId] then
        return false
    end

    local state = allstates[spellId]
    if state == nil then
        state = {}
        allstates[spellId] = state
    end

    state.changed = true
    state.show = true
    state.name, _, state.icon = GetSpellInfo(spellId)
    state.progressType = "timed"
    state.duration = math.max(0.01, aura_env.config.dwellDuration)
    state.expirationTime = GetTime() + state.duration
    state.autoHide = true

    return true
end

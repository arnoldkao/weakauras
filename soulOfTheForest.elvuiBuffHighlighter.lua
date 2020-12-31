-------------------------------------------------------------------------------
-- init

aura_env.sotfState = {
    ["ApplySotf"] = function(self)
        -- Apply the SOTF buff.
    end,

    ["RemoveSotf"] = function(self, timestamp)
        -- Remove the SOTF buff at the specified 'timestamp'.
    end,

    ["Flourish"] = function(self, allstates)
        -- Refresh the duration and expiration time on all states in the
        -- specified 'allstates'.
    end,

    ["ApplyHeal"] = function(self, allstates)
        -- Apply or refresh a HOT effect.  Update the specified 'allstates' as
        -- appropriate.
    end,

    ["RemoveHeal"] = function(self, allstates)
        -- Remove a HOT effect.  Update the specified 'allstates' as
        -- appropriate.
    end
}

aura_env.sotfApplied = false
aura_env.empoweredSpell = nil
aura_env.empoweredCastTime = nil
aura_env.ignoreNext = {}

aura_env.trackedSpellIds = {
    [114108] = true,    -- Soul of the Forest
    [774]    = true,    -- Rejuvenation
    [8936]   = true,    -- Regrowth
    [48438]  = true,    -- Wild Growth
    [155777] = true,    -- Rejuvenation (Germination)
    [197721] = true,    -- Flourish
}

aura_env.getGroupUnitId = function(unitGuid)
    -- Return a unit ID for the specified 'unitGuid' if the unit is in the
    -- current player's group.  Otherwise, return 'nil'.

    for unit in WA_IterateGroupMembers() do
        if UnitGUID(unit) == unitGuid then
            return unit
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- TSU: CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED:SPELL_CAST_SUCCESS

function(allstates, event)
    local timestamp, subevent, _, sourceGuid, _, _, _, destGuid, _, destFlags, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGuid ~= UnitGUID("player") then
        return false
    end

    if aura_env.trackedSpellIds[spellId] == nil then
        return false
    end

    if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0
    or bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) ~= 0 then
        return false
    end

    local destUnit = aura_env.getGroupUnitId(destGuid)
    if destUnit == nil then
        return false
    end

    -- By this point, we're sure that this aura is applied by the player, that
    -- the target is in the player's group, and that the aura is Soul of the
    -- Forest or a HoT that may be empowered by Soul of the Forest.

    local stateKey = spellId .. destGuid

    if subevent == "SPELL_AURA_APPLIED" and spellId == 197721 then
        -- The player used Flourish.  Find all shown states in 'allstates' and
        -- update their durations and expiration times.

        local changed = false
        for _, state in pairs(allstates) do
            if state.show == true then
                local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(state.unit, state.spellId)
                if state.duration ~= duration then
                    state.duration = duration
                    state.expirationTime = expirationTime
                    state.changed = true

                    changed = true
                end
            end
        end

        return changed
    elseif subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_REFRESH"
    or subevent == "SPELL_CAST_SUCCESS" then
        if spellId == 114108 then
            aura_env.sotfApplied = true
            return false
        end

        if aura_env.sotfApplied then
            aura_env.sotfApplied = false
            aura_env.empoweredSpell = spellId
            aura_env.empoweredCastTime = timestamp
        end

        local state = allstates[stateKey]

        if aura_env.ignoreNext.target == destUnit
        and aura_env.ignoreNext.spellId == spellId then
            aura_env.ignoreNext.target = nil
            aura_env.ignoreNext.spellId = nil

            return false
        elseif aura_env.empoweredSpell == spellId
        and aura_env.empoweredCastTime == timestamp then
            if spellId ~= 48438 then
                -- SOTF empowers only the first application of Rejuvenation,
                -- Germination, or Regrowth, even if Memory of the Mother Tree
                -- results in multiple applications at the same time.  Reset
                -- the empowered state so that the following applications do
                -- not show as empowered.

                aura_env.empoweredSpell = nil
                aura_env.empoweredCastTime = nil

                -- Ignore the next 'SPELL_AURA_APPLIED', 'SPELL_AURA_REFRESH',
                -- or 'SPELL_CAST_SUCCESS' event for this same spell on the
                -- same target so that it doesn't overwrite this empowered
                -- state.

                aura_env.ignoreNext.target = destUnit
                aura_env.ignoreNext.spellId = spellId
            end

            if state == nil then
                state = {}
                allstates[stateKey] = state
            end

            state.changed = true
            state.show = true
            state.icon = select(3, GetSpellInfo(spellId))
            state.spellId = spellId
            state.unit = destUnit
            state.progressType = "timed"
            state.autoHide = true

            local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(destUnit, spellId)
            state.duration = duration
            state.expirationTime = expirationTime

            return true
        elseif state ~= nil then
            state.changed = true
            state.show = false

            return true
        else
            return false
        end
    elseif subevent == "SPELL_AURA_REMOVED" then
        if spellId == 114108 then
            -- The SOTF aura is removed after 'SPELL_CAST_SUCCESS', so we've
            -- already set 'aura_env.empoweredSpell' and
            -- 'aura_env.empoweredCastTime', and it's safe to set
            -- 'aura_env.sotfApplied' to false.  ('SPELL_AURA_APPLIED' and
            -- 'SPELL_AURA_REFRESH' sometimes fire before and sometimes fire
            -- after 'SPELL_AURA_REMOVED'.)

            aura_env.sotfApplied = false

            return false
        end

        local state = allstates[stateKey]
        if state ~= nil then
            state.changed = true
            state.show = false

            return true
        end

        return false
    else
        return false
    end
end

-------------------------------------------------------------------------------
-- Animations -> Main -> Fade

function()
    -- Get the ElvUI buff icon frame for this clone, whether it's tracked as a
    -- "Buff" or as a "Buff Indicator".  If it's tracked as both, prefer the
    -- "Buff Indicator".
    --
    -- Here be dragons and use of undocumented (i.e., private) addon behavior.

    local tracksState = function(frame)
        -- Return 'true' if the specified ElvUI button 'frame' tracks
        -- 'aura_env.state.spellId' from the player and is shown.  Otherwise,
        -- return 'false'.

        return frame:IsShown()
            and frame.spellID == aura_env.state.spellId
            and frame.caster == "player"
    end

    local buffIconFrame = aura_env.region.relativeTo

    if buffIconFrame ~= nil
    and tracksState(buffIconFrame) then
        return 0.5
    end

    local unitFrame = WeakAuras.GetUnitFrame(aura_env.state.unit)
    if unitFrame == nil then
        return 0
    end

    buffIconFrame = nil
    for _,frame in ipairs(unitFrame.__owner.AuraWatch) do
        if tracksState(frame) then
            buffIconFrame = frame
            break
        end
    end
    if buffIconFrame == nil then
        for _,frame in ipairs(unitFrame.__owner.Buffs) do
            if tracksState(frame) then
                buffIconFrame = frame
                break
            end
        end
    end

    if buffIconFrame == nil then
        return 0
    end

    aura_env.region:SetAnchor("CENTER", buffIconFrame, "CENTER")
    aura_env.region:SetWidth(buffIconFrame:GetWidth())
    aura_env.region:SetHeight(buffIconFrame:GetHeight())

    return 0.5
end

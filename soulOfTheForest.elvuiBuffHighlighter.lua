-------------------------------------------------------------------------------
--[[ Implementation Notes

There is no consistent order in which 'SPELL_CAST_SUCCESS',
'SPELL_AURA_APPLIED'/'SPELL_AURA_REFRESH', and 'SPELL_AURA_REMOVED' events are
fired.  We therefore assume:

- If a 'SPELL_CAST_SUCCESS' of an empowerable HOT comes after a
  'SPELL_AURA_APPLIED' of SOTF but before a 'SPELL_AURA_REMOVED' of SOTF, then
  the spell cast is empowered by SOTF.
- If SOTF is 'SPELL_AURA_REMOVED' before a 'SPELL_CAST_SUCCESS' of an
  empowerable HOT, but the 'SPELL_CAST_SUCCESS' of an empowerable HOT fires
  later with the same 'timestamp', then that spell cast is empowered by SOTF.
- A 'SPELL_AURA_APPLIED'/'SPELL_AURA_REFRESH' of a spell is empowered only if
  it has the same 'timestamp', 'spellId', and 'targetGuid' as an empowered
  cast.  If the empowered cast is Wild Growth, then the 'targetGuid' is
  ignored.

Because a 'SPELL_CAST_SUCCESS' may come either before or after its
corresponding 'SPELL_AURA_APPLIED'/'SPELL_AURA_REFRESH', each of these events
must update the display state.

We check 'SPELL_CAST_SUCCESS' at all to order amongst 'SPELL_CAST_SUCCESS'
events and determine which are empowered by SOTF.  Two spells may be cast at
the same 'timestamp' due to spell queueing, but only the first of the
'SPELL_CAST_SUCCESS'es would be empowered by SOTF.

'SPELL_AURA_APPLIED'/'SPELL_AURA_REFRESH' cannot be relied upon for deducing
spell cast order.

]]

-------------------------------------------------------------------------------
-- init

aura_env.trackedSpellIds = {
    [114108] = true,    -- Soul of the Forest
    [197721] = true,    -- Flourish
    [774]    = true,    -- Rejuvenation
    [8936]   = true,    -- Regrowth
    [48438]  = true,    -- Wild Growth
    [155777] = true,    -- Rejuvenation (Germination)
}

aura_env.sotfState = {
    ---------------
    -- PRIVATE DATA
    ---------------

    ["__sotfApplied"] = false,
    ["__empoweredTimestamp"] = nil,
    ["__empoweredTarget"] = nil,
    ["__empoweredSpellId"] = nil,

    ------------------------
    -- PRIVATE CLASS METHODS
    ------------------------

    ["__MakeStateKey"] = function(targetGuid, spellId)
        return spellId .. targetGuid
    end,

    ["__GetGroupUnitIdFromUnitGuid"] = function(unitGuid)
        -- Return a unit ID for the unit with the specified 'unitGuid' if the
        -- unit is in the current player's group.  Otherwise, return 'nil'.

        for unit in WA_IterateGroupMembers() do
            if UnitGUID(unit) == unitGuid then
                return unit
            end
        end

        return nil
    end,

    --------------------
    -- PRIVATE ACCESSORS
    --------------------

    ["__IsEmpowered"] = function(self, timestamp, targetGuid, spellId)
        -- Return 'true' if the specified 'spellId' on the specified
        -- 'targetGuid' at the specified 'timestamp' is empowered.  Otherwise,
        -- return 'false'.

        return self.__empoweredTimestamp == timestamp
            and (self.__empoweredTarget == targetGuid or spellId == 48438)
            and self.__empoweredSpellId == spellId
    end,

    ---------------
    -- MANIPULATORS
    ---------------

    ["ApplySotf"] = function(self)
        -- Apply the SOTF buff.

        self.__sotfApplied = true
    end,

    ["RemoveSotf"] = function(self, timestamp)
        -- Remove the SOTF buff at the specified 'timestamp'.

        self.__sotfApplied = false

        if self.__empoweredTimestamp ~= timestamp then
            -- The SOTF buff is newly removed, but we don't know yet what spell
            -- it empowers.

            self.__empoweredTimestamp = timestamp
            self.__empoweredTarget = nil
            self.__empoweredSpellId = nil
        end
    end,

    ["RecordHealCast"] = function(self, timestamp, targetGuid, spellId)
        -- Record the specified 'spellId' on the specified 'targetGuid' as the
        -- last casted heal at the specified 'timestamp', and update the
        -- empowered cast state data as appropriate.

        if self.__sotfApplied
        or (self.__empoweredTimestamp == timestamp and self.__empoweredSpellId == nil) then
            -- The SOTF aura is applied, or it was removed at 'timestamp'
            -- without first empowering a spell.  This 'spellId' at 'timestamp'
            -- consumes the SOTF empowerment.

            self.__sotfApplied = false
            self.__empoweredTimestamp = timestamp
            self.__empoweredTarget = targetGuid
            self.__empoweredSpellId = spellId
        end
    end,

    ["Flourish"] = function(self, allstates)
        -- Refresh the duration and expiration time on all states in the
        -- specified 'allstates'.  Return 'true' if 'allstates' is updated.
        -- Otherwise, return 'false'.

        local changed = false
        for _, state in pairs(allstates) do
            if state.show == true then
                local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(state.unit, state.spellId, "PLAYER")

                state.duration = duration
                state.expirationTime = expirationTime
                state.changed = true

                changed = true
            end
        end

        return changed
    end,

    ["ApplyHeal"] = function(self, allstates, timestamp, targetGuid, spellId)
        -- Apply or refresh a HOT effect with the specified 'spellId' to the
        -- unit with the specified 'targetGuid' at the specified 'timestamp'.
        -- Update the specified 'allstates' as appropriate.  Return 'true' if
        -- 'allstates' is updated.  Otherwise, return 'false'.

        local stateKey = self.__MakeStateKey(targetGuid, spellId)
        local state = allstates[stateKey]

        if self:__IsEmpowered(timestamp, targetGuid, spellId) then
            -- Insert or update the state in 'allstates'.

            if state == nil then
                state = {}
                allstates[stateKey] = state
            end

            local targetUnit = self.__GetGroupUnitIdFromUnitGuid(targetGuid)

            state.changed = true
            state.show = true
            state.icon = select(3, GetSpellInfo(spellId))
            state.spellId = spellId
            state.unit = targetUnit
            state.progressType = "timed"
            state.autoHide = true

            local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(targetUnit, spellId, "PLAYER")
            state.duration = duration
            state.expirationTime = expirationTime

            return true
        else
            -- Remove the state from 'allstates'.

            if state == nil then
                return false
            end

            state.changed = true
            state.show = false

            return true
        end
    end,

    ["RemoveHeal"] = function(self, allstates, targetGuid, spellId)
        -- Remove a HOT effect with the specified 'spellId' from the unit with
        -- the specified 'targetGuid'.  Update the specified 'allstates' as
        -- appropriate.

        local stateKey = self.__MakeStateKey(targetGuid, spellId)
        local state = allstates[stateKey]

        if state == nil then
            return false
        end

        state.changed = true
        state.show = false

        return true
    end,
}

-------------------------------------------------------------------------------
-- TSU: CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED:SPELL_CAST_SUCCESS

function(allstates, event)
    local timestamp, subevent, _, sourceGuid, _, _, _, targetGuid, _, targetFlags, _, spellId = CombatLogGetCurrentEventInfo()

    -- Ignore events not caused by the player.

    if sourceGuid ~= UnitGUID("player") then
        return false
    end

    -- Ignore untracked spell IDs.

    if aura_env.trackedSpellIds[spellId] == nil then
        return false
    end

    -- Ignore events not affecting the player or a group member, unless the
    -- spell is Wild Growth.  (Wild Growth's 'SPELL_CAST_SUCCESS' event never
    -- specifies a target.)

    if spellId ~= 48438
    and (bit.band(targetFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0
    or bit.band(targetFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) ~= 0) then
        return false
    end

    -- Update state.

    local sotfState = aura_env.sotfState;

    if subevent == "SPELL_CAST_SUCCESS" and spellId ~= 197721 then
        sotfState:RecordHealCast(timestamp, targetGuid, spellId)
        if spellId == 48438 then
            -- Wild Growth's 'SPELL_CAST_SUCCESS' has no target.  The only unit
            -- for which we'd see a 'SPELL_AURA_APPLIED' before we see the
            -- 'SPELL_CAST_SUCCESS' is the player, so we specially check if the
            -- player has a Wild Growth aura applied by this player with a
            -- duration and expiration time that imply that the aura was
            -- applied just now.

            local _, _, _, _, duration, expirationTime = WA_GetUnitBuff("player", spellId, "PLAYER")

            local currentTime = GetTime()

            if expirationTime ~= nil
            and expirationTime < currentTime + duration + 0.1
            and expirationTime > currentTime + duration - 0.1 then
                return sotfState:ApplyHeal(allstates,
                                           timestamp,
                                           sourceGuid,
                                           spellId)
            end
        else
            return sotfState:ApplyHeal(allstates,
                                       timestamp,
                                       targetGuid,
                                       spellId)
        end
    elseif subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_REFRESH" then
        if spellId == 114108 then       -- Soul of the Forest
            sotfState:ApplySotf()
            return false
        elseif spellId == 197721 then   -- Flourish
            return sotfState:Flourish(allstates)
        else
            return sotfState:ApplyHeal(allstates,
                                       timestamp,
                                       targetGuid,
                                       spellId)
        end
    elseif subevent == "SPELL_AURA_REMOVED" then
        if spellId == 114108 then       -- Soul of the Forest
            sotfState:RemoveSotf(timestamp)
            return false
        elseif spellId == 197721 then   -- Flourish
            return false
        else
            return sotfState:RemoveHeal(allstates, targetGuid, spellId)
        end
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

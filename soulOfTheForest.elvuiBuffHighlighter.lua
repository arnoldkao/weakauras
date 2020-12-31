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

    -----------------------
    -- PRIVATE MANIPULATORS
    -----------------------

    ["__EmpowerHeal"] = function(self, timestamp, spellId)
        -- Try to empower an application of the specified 'spellId' at the
        -- specified 'timestamp'.  Return 'true' if the application is
        -- empowered.  Otherwise, return 'false'.

        if not self.__sotfApplied
        and (self.__empoweredTimestamp ~= timestamp or self.__empoweredSpellId ~= nil) then
            return false
        end

        -- The SOTF aura is applied, or it was removed at 'timestamp' without
        -- first empowering a spell.  This 'spellId' at 'timestamp' is
        -- empowered.

        self.__sotfApplied = false

        if spellId == 48438 then
            -- This is an application of Wild Growth.  Any following
            -- applications of Wild Growth at 'timestamp' will also be
            -- empowered.

            self.__empoweredTimestamp = timestamp
            self.__empoweredSpellId = spellId
        else
            -- This is an application of another heal.  Empower this
            -- application, but prevent all following spells from being
            -- empowered, even if they are at 'timestamp', until the next
            -- application of the SOTF buff.

            self.__empoweredTimestamp = nil
            self.__empoweredSpellId = nil
        end

        return true
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

        if self.__empoweredTimestamp == timestamp then
            -- The SOTF buff has already been consumed at 'timestamp' for a
            -- particular heal.  Do nothing.

            return
        end

        self.__empoweredTimestamp = timestamp
        self.__empoweredSpellId = nil
    end,

    ["Flourish"] = function(self, allstates)
        -- Refresh the duration and expiration time on all states in the
        -- specified 'allstates'.  Return 'true' if 'allstates' is updated.
        -- Otherwise, return 'false'.

        local changed = false
        for _, state in pairs(allstates) do
            if state.show == true then
                local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(state.unit, state.spellId)

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

        if self:__EmpowerHeal(timestamp, spellId) then
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

            local _, _, _, _, duration, expirationTime = WA_GetUnitBuff(targetUnit, spellId)
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
-- TSU: CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED

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

    -- Ignore events not affecting the player or a group member.

    if bit.band(targetFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0
    or bit.band(targetFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) ~= 0 then
        return false
    end

    -- Update state.

    local sotfState = aura_env.sotfState;

    if subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_REFRESH" then
        if spellId == 114108 then       -- Soul of the Forest
            sotfState:ApplySotf()
            return false
        elseif spellId == 197721 then   -- Flourish
            return sotfState:Flourish()
        else
            return sotfState:ApplyHeal(allstates,
                                       timestamp,
                                       targetGuid,
                                       spellId)
        end
    elseif subevent == "SPELL_AURA_REMOVED" then
        if spellId == 114108 then       -- Soul of the Forest
            sotfState:RemoveSotf()
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

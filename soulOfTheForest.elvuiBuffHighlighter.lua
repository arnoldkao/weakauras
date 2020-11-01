-- init
aura_env.sotfExpirationTime = 0     -- in fractional seconds since epoch
aura_env.clockAdjustment = time() - GetTime()   -- add to local time to get unix time

aura_env.trackedSpellIds = {
    [114108]=true,  -- Soul of the Forest
    [774]=true,     -- Rejuvenation
    [8936]=true,    -- Regrowth
    [48438]=true,   -- Wild Growth
    [155777]=true,  -- Rejuvenation (Germination)
    [197721]=true,  -- Flourish
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

aura_env.tracksState = function(frame)
    -- Return 'true' if the specified ElvUI button 'frame' tracks
    -- 'aura_env.state.spellId' from the player and is shown.  Otherwise,
    -- return 'false'.

    return frame:IsShown()
        and frame.spellID == aura_env.state.spellId
        and frame.caster == "player"
end

-- trigger: CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED, PLAYER_DEAD
function(allstates, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGuid, _, _, _, destGuid, _, destFlags, _, spellId = CombatLogGetCurrentEventInfo()

        if sourceGuid ~= UnitGUID("player") then
            return false
        end

        if not aura_env.trackedSpellIds[spellId] then
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

        -- By this point, we're sure that this aura is applied by the player,
        -- that the target is in the player's group, and that the aura is Soul
        -- of the Forest or a HoT that may be empowered by Soul of the Forest.

        local stateKey = spellId .. destGuid

        if subevent == "SPELL_AURA_APPLIED" and spellId == 197721 then
            -- The player used Flourish.  Find all shown states in 'allstates'
            -- and update their durations and expiration times.

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
        elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            if spellId == 114108 then
                aura_env.sotfExpirationTime = select(6, WA_GetUnitBuff(destUnit, spellId)) + aura_env.clockAdjustment
                return false
            end

            local state = allstates[stateKey]
            if aura_env.sotfExpirationTime > timestamp then
                if state == nil then
                    state = {}
                    allstates[stateKey] = state
                end

                if spellId == 48438 then
                    -- This is an empowered Wild Growth.  Change the
                    -- expiration time on SOTF to some time less than one GCD
                    -- from now so that all applications of Wild Growth are
                    -- tracked in 'allstates'.

                    aura_env.sotfExpirationTime = timestamp + 0.1
                else
                    aura_env.sotfExpirationTime = 0
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
                -- The SOTF aura is removed before the empowered spell is
                -- applied, so we ignore the "SPELL_AURA_REMOVED" subevent for
                -- the SOTF aura and instead rely on checking the expiration
                -- time against the current time (as provided by the
                -- 'timestamp' of each CLEU event).  Note that this results in
                -- a display bug if the SOTF aura is removed by any means
                -- other than consumption -- for example, by death or
                -- '/cancelaura'.  The death case is covered by the
                -- "PLAYER_DEAD" event.

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
    elseif event == "PLAYER_DEAD" then
        aura_env.sotfExpirationTime = 0
        return false
    end
end

-- Animations -> Main -> Fade
function()
    -- Get the ElvUI buff icon frame for this clone, whether it's tracked as a
    -- "Buff" or as a "Buff Indicator".  If it's tracked as both, prefer the
    -- "Buff Indicator".

    if aura_env.region
    and aura_env.region.anchor
    and aura_env.tracksState(aura_env.region.anchor) then
        return 0.5
    end

    local unitFrame = WeakAuras.GetUnitFrame(aura_env.state.unit)
    if unitFrame == nil then
        return 0
    end

    local buffIconFrame = nil
    for _,frame in ipairs(unitFrame.__owner.AuraWatch) do
        if aura_env.tracksState(frame) then
            buffIconFrame = frame
            break
        end
    end
    if buffIconFrame == nil then
        for _,frame in ipairs(unitFrame.__owner.Buffs) do
            if aura_env.tracksState(frame) then
                buffIconFrame = frame
                break
            end
        end
    end

    if buffIconFrame == nil then
        return 0
    end

    if aura_env.region.anchor ~= buffIconFrame then
        aura_env.region:ClearAllPoints()
        aura_env.region:SetAllPoints(buffIconFrame)
    end

    aura_env.region.anchor = buffIconFrame

    return 0.5
end

-- init
aura_env.damageHistory = {}
aura_env.ignoreUnitGuidDeath = {}

aura_env.getSpellText = function(spell, school)
    -- Return a formatted string describing the specified 'spell' of the
    -- optionally specified 'school'.  If 'spell' is a string, the returned
    -- human-readable string will contain 'spell' directly.  Otherwise, if
    -- 'spell' is a number, the returned string will link to 'spell'. 'school'
    -- is a bitmask where each bit keys into
    -- 'COMBATLOG_DEFAULT_COLORS.schoolColoring'.

    local text = nil
    if type(spell) == "number" then
        local spellName, _ = GetSpellInfo(spell)
        text = "|Hspell:" .. spell .. "|h[" .. spellName .. "]|h"
    else
        text = "[" .. spell .. "]"
    end

    local schoolColor = _G.COMBATLOG_DEFAULT_COLORS.schoolColoring[school]
    if schoolColor ~= nil then
        -- The input 'school' is not exactly one spell school.  Default to
        -- white.

        schoolColor = CreateColor(schoolColor.r,
                                  schoolColor.g,
                                  schoolColor.b,
                                  1)
        text = schoolColor:WrapTextInColorCode(text)
    end

    return text
end

aura_env.reportCauseOfDeath = function(unitGuid, unit)
    -- Print a report for the cause of death for the specified 'unitGuid',
    -- which is also referred to by 'unit', and clear the damage taken history
    -- for 'unitGuid'

    local deathReport = "Cause of Death [" .. WA_ClassColorName(unit) .. "]:"
    local unitHistory = aura_env.damageHistory[unitGuid]

    if unitHistory == nil or #unitHistory.events == 0 then
        deathReport = deathReport .. "\n  <<Unknown>>"
    else
        for i = 1, #unitHistory.events do
            local event = unitHistory.events[i]
            deathReport = (
                deathReport .. "\n  "
                .. aura_env.getSpellText(event.spell, event.school) .. ": "
                .. AbbreviateNumbers(event.amount))
        end

        -- Clear the history.

        unitHistory.events = {}
        unitHistory.sum = 0
    end

    print(deathReport)
end

-- trigger: WA_CAUSEOFDEATH_DEFERRED, CLEU:UNIT_DIED, CLEU:SPELL_AURA_APPLIED, CLEU:SWING_DAMAGE, CLEU:RANGE_DAMAGE, CLEU:SPELL_DAMAGE, CLEU:SPELL_PERIODIC_DAMAGE, CLEU:SPELL_BUILDING_DAMAGE, CLEU:ENVIRONMENTAL_DAMAGE, CLEU:SWING_INSTAKILL, CLEU:RANGE_INSTAKILL, CLEU:SPELL_INSTAKILL, CLEU:SPELL_PERIODIC_INSTAKILL, CLEU:SPELL_BUILDING_INSTAKILL, CLEU:ENVIRONMENTAL_INSTAKILL
function(event, ...)
    -- Note that this function never triggers because we're not interested in
    -- displaying anything except by 'print'ing.

    if event == "WA_CAUSEOFDEATH_DEFERRED" then
        aura_env.reportCauseOfDeath(...)
        return
    end

    local subevent = select(2, ...)
    if subevent == nil then
        return
    end

    -- Ignore events affecting units not in the group.

    local unitGuid = select(8, ...)
    local unit = nil
    for groupMember in WA_IterateGroupMembers() do
        if UnitGUID(groupMember) == unitGuid then
            unit = groupMember
            break
        end
    end
    if unit == nil then
        return
    end

    if subevent == "UNIT_DIED" then
        if aura_env.ignoreUnitGuidDeath[unitGuid] ~= nil then
            aura_env.ignoreUnitGuidDeath[unitGuid] = nil
        else
            aura_env.reportCauseOfDeath(unitGuid, unit)
        end
    elseif subevent == "SPELL_AURA_APPLIED" then
        local spellId = select(12, ...)
        spellId = tonumber(spellId)

        if spellId == 45181         -- Cheated Death
        or spellId == 87024         -- Cauterized
        or spellId == 209261        -- Uncontained Fel
        or spellId == 295047 then   -- Touch of the Everlasting
            aura_env.reportCauseOfDeath(unitGuid, unit)
        elseif spellId == 27827 then    -- Spirit of Redemption
            -- Delay the report by a second, since this aura is applied before
            -- the combat log reports the damage event that took the unit to 0
            -- health.

            C_Timer.After(1, function() WeakAuras.ScanEvents("WA_CAUSEOFDEATH_DEFERRED", unitGuid, unit) end)

            -- Also save this unit GUID so that we can ignore its impending
            -- 'UNIT_DIED' event.

            aura_env.ignoreUnitGuidDeath[unitGuid] = true
        end
    elseif subevent:find("_DAMAGE") ~= nil then
        -- Keep track of the damage taken by this group member.

        local unitHistory = aura_env.damageHistory[unitGuid]
        if unitHistory == nil then
            unitHistory = { events = {}, sum = 0 }
            aura_env.damageHistory[unitGuid] = unitHistory
        end

        -- Extract the event's information.

        local spell = nil
        local amount = nil
        local school = nil
        local _ = nil
        if subevent:find("SWING_") then
            spell = "Melee"
            amount, _, school = select(12, ...)
        elseif subevent:find("ENVIRONMENTAL_") then
            spell = select(12, ...)
            amount, _, school = select(13, ...)
        else
            spell = select(12, ...)
            spell = tonumber(spell)
            amount, _, school = select(15, ...)
        end

        -- Add the new damage event to the history (at the end of the array).

        unitHistory.sum = unitHistory.sum + amount
        table.insert(unitHistory.events, { amount = amount, spell = spell, school = school })

        -- Remove damage events from the history (at the beginning of the
        -- array) until removing one more would reduce the sum below the
        -- configured %MaxHP for history.

        local maxHealth = UnitHealthMax(unit)
        local sumCutoff = maxHealth * aura_env.config.percentHealthHistory / 100

        while #unitHistory.events > 0 do
            local sumAfterRemoval = unitHistory.sum - unitHistory.events[1].amount
            if sumAfterRemoval < sumCutoff then
                break
            end

            unitHistory.sum = sumAfterRemoval
            table.remove(unitHistory.events, 1)
        end
    elseif subevent:find("_INSTAKILL") ~= nil then
        -- Replace the damage history table for this unit to contain just this
        -- instakill event.

        local amount = UnitHealthMax(unit)
        local unitHistory = { events = {}, sum = 0 }
        aura_env.damageHistory[unitGuid] = unitHistory

        local spell = nil
        local school = nil
        local _ = nil
        if subevent:find("SWING_") then
            spell = "Melee Instakill"
        elseif subevent:find("ENVIRONMENTAL_") then
            spell = select(12, ...)
            spell = spell .. " Instakill"
        else
            spell, _, school = select(12, ...)
            spell = tonumber(spell)
        end

        -- Insert the damage event into the new damage history array.

        unitHistory.sum = unitHistory.sum + amount
        table.insert(unitHistory.events, { amount = amount, spell = spell, school = nil })
    end
end
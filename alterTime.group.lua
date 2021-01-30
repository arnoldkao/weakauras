-------------------------------------------------------------------------------
-- init

aura_env.lgf = LibStub("LibGetFrame-1.0")

-------------------------------------------------------------------------------
-- show

local region = aura_env.region
local frame = aura_env.lgf.GetFrame(aura_env.state.unit)

region:ClearAllPoints()
region:SetPoint("CENTER", frame, "CENTER")
region:SetRegionWidth(frame:GetWidth())
region:SetRegionHeight(frame:GetHeight())
region:SetParent(frame)

region.bar.spark:SetHeight(frame:GetHeight() * 1.5)

-------------------------------------------------------------------------------
-- trigger (TSU): CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REMOVED

function(allstates, event, ...)
    if ... == nil then
        return false
    end

    local subevent = select(2, ...)
    local sourceGuid = select(4, ...)
    local sourceFlags = select(6, ...)
    local spellName = select(13, ...)

    if not bit.band(sourceFlags, 0x07) or spellName ~= "Alter Time" then
        return false
    end

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

    local state = allstates[sourceGuid]
    if subevent == "SPELL_AURA_REMOVED" then
        if state == nil then
            return false
        end

        state.changed = true
        state.show = false

        return true
    else    -- subevent == "SPELL_AURA_APPLIED"
        if state == nil then
            state = {}
            allstates[sourceGuid] = state
        end

        state.changed = true
        state.show = true
        state.progressType = "static"
        state.value = UnitHealth(unit)
        state.total = UnitHealthMax(unit)
        state.unit = unit

        return true
    end
end

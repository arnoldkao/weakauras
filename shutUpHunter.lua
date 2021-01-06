-------------------------------------------------------------------------------
-- init

local groupUnitIdForGuid = function(unitGuid)
    for unit in WA_IterateGroupMembers() do
        if UnitGUID(unit) == unitGuid then
            return unit
        end
    end

    return nil
end

local unitGuidIsGroupHunter = function(unitGuid)
    local unit = groupUnitIdForGuid(unitGuid)
    if unit == nil then
        return false
    end

    local _, unitClass = UnitClass(unit)
    return unitClass == "HUNTER"
end

local aura_env = aura_env
aura_env.stupidHunterGuids = {}

aura_env.countdownFilter = function(chatFrame, event, message, authorName, _, _, _, _, _, _, _, _, _, authorGuid)
    -- Counters https://wago.io/IzZwQ8AW-/1

    if not unitGuidIsGroupHunter(authorGuid) then
        return false
    end

    if message:match("^ *Wild Spirits on the ground, TANK DON'T MOVE *$") then
        aura_env.stupidHunterGuids[authorGuid] = true
        return true
    end

    if message:match("^ *Tank can move! *$") then
        aura_env.stupidHunterGuids[authorGuid] = nil
        return true
    end

    if aura_env.stupidHunterGuids[authorGuid] and message:match("^ *[1-9] *$") then
        return true
    end

    return false
end

aura_env.targetInWildSpiritsFilter = function(chatFrame, event, message, authorName, _, _, _, _, _, _, _, _, _, authorGuid)
    -- Counters https://wago.io/UGRQJSmz_/1

    return message:match(" in wild spirits *$") and unitGuidIsGroupHunter(authorGuid)
end

aura_env.events = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

-------------------------------------------------------------------------------
-- show

for _, event in pairs(aura_env.events) do
    ChatFrame_AddMessageEventFilter(event, aura_env.targetInWildSpiritsFilter)
    ChatFrame_AddMessageEventFilter(event, aura_env.countdownFilter)
end

-------------------------------------------------------------------------------
-- hide

for _, event in pairs(aura_env.events) do
    ChatFrame_RemoveMessageEventFilter(event, aura_env.targetInWildSpiritsFilter)
    ChatFrame_RemoveMessageEventFilter(event, aura_env.countdownFilter)
end

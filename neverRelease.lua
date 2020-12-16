-- trigger: PLAYER_DEAD, PLAYER_ALIVE, RESURRECT_REQUEST, CHAT_MSG_RAID, CHAT_MSG_RAID_LEADER
function(event, arg1)
    if ((event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER")
    and arg1 ~= nil
    and string.lower(arg1):match("^%s*release%s*$") ~= nil) then
        return false
    end

    return UnitIsDead("player") and ResurrectGetOfferer() == nil
end

-- untrigger
function()
    return true
end

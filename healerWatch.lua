-------------------------------------------------------------------------------
-- init

C_ChatInfo.RegisterAddonMessagePrefix("HealerWatch_WA")

aura_env.nameToUnitMap = {}
aura_env.realmNameSuffix = GetRealmName():gsub(" ", "")
aura_env.playerNameWithRealm = (GetUnitName("player")
                                    .. '-' .. aura_env.realmNameSuffix)

function aura_env.canAccessUnitMana(unit)
    -- Return 'true' if we can query for 'unit's mana.  Otherwise, return
    -- 'false'.

    return Enum.PowerType.Mana == UnitPowerType(unit) or unit == "player"
end

function aura_env.getManaPercentValue(unit)
    -- Return the percentage mana that the specified 'unit' has, out of 100.
    -- If 'unit's mana cannot be retrieved, return 0 instead.

    return (UnitPower(unit, Enum.PowerType.Mana) * 100
                / (UnitPowerMax(unit, Enum.PowerType.Mana) or 1))
end

local drinkingBuffNames = {
    ["Food & Drink"] = true,
    ["Drink"] = true,
    ["Refreshment"] = true
}

function aura_env.isDrinking(unit)
    -- Return 'true' if the specified 'unit' is drinking.  Otherwise, return
    -- 'false'.

    for i = 1, 40 do
        local name, _ = UnitBuff(unit, i)
        if drinkingBuffNames[name] ~= nil then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- TSU: PLAYER_ROLES_ASSIGNED, UNIT_POWER_UPDATE, UNIT_HEALTH, CHAT_MSG_ADDON, UNIT_AURA

function(allstates, event, ...)
    if event == "PLAYER_ROLES_ASSIGNED" then
        -- Clear and repopulate 'allstates' and 'aura_env.nameToUnitMap' with
        -- the healers in the group.

        for k, _ in pairs(allstates) do
            allstates[k] = nil
        end

        local nameToUnitMap = {}

        for unit in WA_IterateGroupMembers() do
            if UnitGroupRolesAssigned(unit) == "HEALER" then
                local unitName, unitRealm = UnitName(unit)
                if unitRealm == nil then
                    unitRealm = aura_env.realmNameSuffix
                end

                local unitName = unitName .. "-" .. unitRealm

                nameToUnitMap[unitName] = unit

                allstates[unit] = {
                    ["show"] = true,
                    ["unit"] = unit,
                    ["progressType"] = "static",
                    ["autoHide"] = false,
                    ["total"] = 100,

                    ["changed"] = true,
                    ["value"] = aura_env.getManaPercentValue(unit)
                }
            end
        end

        aura_env.nameToUnitMap = nameToUnitMap

        return true
    elseif event == "UNIT_POWER_UPDATE" then
        local unit, _ = ...
        local state = allstates[unit]
        if state == nil then
            return false
        end

        if aura_env.canAccessUnitMana(unit) then
            state["changed"] = true
            state["value"] = aura_env.getManaPercentValue(unit)

            return true
        end

        return false
    elseif event == "UNIT_HEALTH" then
        local unit, _ = ...
        local state = allstates[unit]
        if state == nil then
            return false
        end

        local wasDead = state["dead"]
        local isDead = UnitIsDeadOrGhost(unit)

        if wasDead ~= isDead then
            state["changed"] = true
            state["dead"] = isDead

            return true
        end

        return false
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...

        if prefix ~= "HealerWatch_WA"
        or sender == aura_env.playerNameWithRealm then
            return false
        end

        if channel ~= "PARTY"
        and channel ~= "RAID"
        and channel ~= "INSTANCE_CHAT" then
            return false
        end

        local unit = aura_env.nameToUnitMap[sender]
        if unit == nil then
            return false
        end

        if not aura_env.canAccessUnitMana(unit) then
            local state = allstates[unit]
            state["changed"] = true
            state["value"] = tonumber(message)

            return true
        end

        return false
    elseif event == "UNIT_AURA" then
        local unit, _ = ...
        local state = allstates[unit]
        if state == nil then
            return false
        end

        local wasDrinking = state["drinking"]
        local isDrinking = aura_env.isDrinking(unit)

        if wasDrinking ~= isDrinking then
            state["changed"] = true
            state["drinking"] = isDrinking

            return true
        end

        return false
    end
end

-------------------------------------------------------------------------------
-- Custom Variables

{
    -- Standard conditions:
    ["value"] = true,
    ["total"] = true,

    -- Custom conditions:
    ["unit"] = "string",
    ["dead"] = "bool",
    ["drinking"] = "bool"
}

-------------------------------------------------------------------------------
-- mana publisher custom text function

function()
    local now = GetTime()
    if aura_env.lastTime ~= nil and aura_env.lastTime + 2 > now then
        return ""
    end
    aura_env.lastTime = now

    local targetChannel
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        targetChannel = "INSTANCE_CHAT"
    elseif UnitInRaid("player") then
        targetChannel = "RAID"
    elseif UnitInParty("player") then
        targetChannel = "PARTY"
    else
        return ""
    end

    local mana = (UnitPower("player", Enum.PowerType.Mana) * 100
                    / UnitPowerMax("player", Enum.PowerType.Mana))
    C_ChatInfo.SendAddonMessage("HealerWatch_WA", mana, targetChannel)

    return ""
end

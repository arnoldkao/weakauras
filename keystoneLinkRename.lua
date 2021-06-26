local aura_env = aura_env

aura_env.nicknames = {
    [375] = aura_env.config.mists,
    [376] = aura_env.config.wake,
    [377] = aura_env.config.side,
    [378] = aura_env.config.halls,
    [379] = aura_env.config.plague,
    [380] = aura_env.config.depths,
    [381] = aura_env.config.spires,
    [382] = aura_env.config.theater
}

if not aura_env.installed then
    if aura_env.config.loginMessage then
        print('Keystone Link Rename: registering chat event filter')
    end

    aura_env.installed = true

    local renameKeystoneLinks = function(chatFrame, event, messageBody, ...)
        local _, _, keystoneMapId = messageBody:find("|Hkeystone:180653:(%d+):")
        if keystoneMapId == nil then
            return false, messageBody, ...
        end

        keystoneMapId = tonumber(keystoneMapId)
        local localizedName, _ = C_ChallengeMode.GetMapUIInfo(keystoneMapId)
        local nickname = aura_env.nicknames[keystoneMapId]
        if nickname == nil or nickname == "" then
            return false, messageBody, ...
        end

        local modifiedMessageBody = messageBody:gsub(localizedName, nickname)

        return false, modifiedMessageBody, ...
    end

    local events = {
        "CHAT_MSG_GUILD",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
    }

    for _, event in pairs(events) do
        ChatFrame_AddMessageEventFilter(event, renameKeystoneLinks)
    end
end

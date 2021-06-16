-------------------------------------------------------------------------------
-- init

LoadAddOn("Blizzard_TalentUI")

local button

aura_env.tomeItemId = 173049

aura_env.setMacroText = function()
    local itemName = GetItemInfo(aura_env.tomeItemId)
    if itemName ~= nil then
        button:SetAttribute("macrotext", "/use " .. itemName)
    end
end

local buttonName = 'WA_TomeTalentWindowButton'

if _G[buttonName] == nil then
    button = CreateFrame("Button",
                         buttonName,
                         aura_env.region,
                         "SecureActionButtonTemplate")

    button:SetAllPoints()
    button:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    button:SetAttribute("type", "macro")

    aura_env.setMacroText()
end

-------------------------------------------------------------------------------
-- trigger: GET_ITEM_INFO_RECEIVED

function(event, itemId, success)
    if itemId == aura_env.tomeItemId and success then
        aura_env.setMacroText()
    end
end

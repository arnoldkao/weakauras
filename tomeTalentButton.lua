-------------------------------------------------------------------------------
-- init

LoadAddOn("Blizzard_TalentUI")

if aura_env.button == nil then
    local button = CreateFrame("Button",
                               nil,
                               nil,
                               "SecureActionButtonTemplate")

    button:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    button:SetAttribute("type", "item")
    button:SetAttribute("item", "item:173049")

    button:SetParent(aura_env.region)
    button:SetAllPoints()

    aura_env.button = button
end

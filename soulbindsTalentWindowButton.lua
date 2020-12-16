--[[ TODO

- Change button texture/text according to covenant/soulbind/traits/conduits

]]--

-------------------------------------------------------------------------------
-- init

LoadAddOn("Blizzard_TalentUI")
LoadAddOn("Blizzard_Soulbinds")

local button = CreateFrame("Button",
                           "WA_SoulbindsTalentWindowButton",
                           aura_env.region,
                           "SecureActionButtonTemplate")

local buttonScript = function()
    if SoulbindViewer:IsVisible() then
        SoulbindViewer.CloseButton:Click()
    else
        SoulbindViewer:Open()
    end
end

button:SetAllPoints()
button:RegisterForClicks("LeftButtonDown")
button:SetScript("OnClick", buttonScript)

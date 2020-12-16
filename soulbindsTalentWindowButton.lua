--[[ TODO

- Change button texture/text according to covenant/soulbind/traits/conduits

]]--

-------------------------------------------------------------------------------
-- init

LoadAddOn("Blizzard_TalentUI")
LoadAddOn("Blizzard_Soulbinds")

local buttonName = 'WA_SoulbindsTalentWindowButton'

if _G[buttonName] == nil then
    local button = CreateFrame("Button",
                               buttonName,
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
end

-------------------------------------------------------------------------------
-- trigger: SOULBIND_ACTIVATED, WA_SOULBINDSTALENTWINDOWBUTTON_DEFERRED

function(event)
    local model = aura_env.region.model

    if model == nil then
        -- Schedule a retrigger on the next rendered frame, when 'model' is not
        -- 'nil'.

        if event == 'SOULBIND_ACTIVATED' then
            C_Timer.After(0, function() WeakAuras.ScanEvents("WA_SOULBINDSTALENTWINDOWBUTTON_DEFERRED") end)
        end

        return true
    end

    local soulbindId = C_Soulbinds.GetActiveSoulbindID()
    local soulbindData = C_Soulbinds.GetSoulbindData(soulbindId)
    local displayInfoId = soulbindData.modelSceneData.creatureDisplayInfoID

    model:SetDisplayInfo(displayInfoId)

    return true
end

-------------------------------------------------------------------------------
-- untrigger

function()
    return false
end

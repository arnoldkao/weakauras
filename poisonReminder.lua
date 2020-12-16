-- init
local button = CreateFrame("Button",
                           "WA_PoisonReminder",
                           aura_env.region,
                           "SecureActionButtonTemplate")

button:SetAllPoints()
button:SetAttribute("unit","player")
button:RegisterForClicks("LeftButtonDown", "RightButtonDown")

button:SetAttribute("type1", "spell")
button:SetAttribute("type2", "spell")
button:SetAttribute("shift-type1", "spell")
button:SetAttribute("shift-type2", "spell")

button:SetAttribute("spell1", 315584)
button:SetAttribute("shift-spell1", 8679)
button:SetAttribute("spell2", 3408)
button:SetAttribute("shift-spell2", 5761)

-- custom text
function()
    -- Note that we set the icon on trigger update rather than on show, since
    -- applying crippling poison results in a trigger update but does not
    -- result in the "on show" logic being called.

    if GetSpecialization() == 1 then
        aura_env.region:SetIcon(132290)
        return "Deadly"
    else
        aura_env.region:SetIcon(132273)
        return "Instant"
    end
end

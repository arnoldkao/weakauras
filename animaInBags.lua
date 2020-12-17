-- display custom text
function()
    return aura_env.animaAsCurrency, aura_env.animaInBags, aura_env.animaTotal
end

--------------------------------------------------------------------------------
-- trigger (status): BAG_UPDATE_DELAYED, CURRENCY_DISPLAY_UPDATE
-- based on https://wago.io/d3T2l8gld/3
function(event, ...)
    if event == 'CURRENCY_DISPLAY_UPDATE' then
        local currencyId, _ = ...
        if currencyId ~= 1813 then
            return true
        end
    end

    local animaAsCurrency = 0
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(1813)
    if currencyInfo ~= nil then
        animaAsCurrency = currencyInfo.quantity
    end

    local animaInBags = 0

    for bag = 0, NUM_BAG_SLOTS do
        local bagSize = GetContainerNumSlots(bag)
        for slot = 1, bagSize do
            local _, stack, _, quality = GetContainerItemInfo(bag, slot)
            if stack then
                local itemId = GetContainerItemID(bag, slot);
                if C_Item.IsAnimaItemByID(itemId) then
                    if (quality == 2) and (itemId ~= 183727) then
                        -- green, but not 'Resonance of Conflict'

                        animaInBags = animaInBags + 5 * stack
                    end

                    if quality == 3 then
                        -- blue

                        animaInBags = animaInBags + 35 * stack
                    end

                    if quality == 4 then
                        -- purple

                        animaInBags = animaInBags + 250 * stack
                    end

                    if itemId == 183727 then
                        -- 'Resonance of Conflict'

                        animaInBags = animaInBags + 3 * stack
                    end
                end
            end
        end
    end

    aura_env.animaInBags = animaInBags
    aura_env.animaAsCurrency = animaAsCurrency
    aura_env.animaTotal = animaInBags + animaAsCurrency

    return true
end

--------------------------------------------------------------------------------
-- name info
-- This is here to force a trigger update.
function()
    return GetTime()
end

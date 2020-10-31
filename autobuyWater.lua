-- trigger: MERCHANT_SHOW, MERCHANT_CLOSED
function(event)
    return event == "MERCHANT_SHOW"
end

-- untrigger
function(event)
    return event == "MERCHANT_CLOSED"
end

-- on show
local count = GetItemCount(aura_env.config.itemId, false, false)
local deficit = aura_env.config.maxCount - count
if deficit > 0 then
    for itemIndex = 1, GetMerchantNumItems() do
        if GetMerchantItemID(itemIndex) == aura_env.config.itemId then
            local _, _, _, quantity = GetMerchantItemInfo(itemIndex)
            BuyMerchantItem(itemIndex, deficit)
        end
    end
end
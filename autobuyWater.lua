-- trigger: MERCHANT_SHOW
function(event, ...)
    local count = GetItemCount(aura_env.config.itemId, false, false) or 0
    local deficit = aura_env.config.maxCount - count
    if deficit > 0 then
        for itemIndex = 1, GetMerchantNumItems() do
            if GetMerchantItemID(itemIndex) == aura_env.config.itemId then
                -- We get an error if we try to buy more than one stack in one
                -- call to 'BuyMerchantItem', so we loop.

                while deficit ~= 0 do
                    local loopBuyCount
                    if deficit > 20 then
                        loopBuyCount = 20
                    else
                        loopBuyCount = deficit
                    end

                    deficit = deficit - loopBuyCount

                    BuyMerchantItem(itemIndex, loopBuyCount)
                end
            end
        end
    end

    return false
end

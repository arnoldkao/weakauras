-------------------------------------------------------------------------------
-- init

local animaItems = WA_ANIMAINBAGS_ANIMAITEMS
local animaItemsLoaded = true

if animaItems == nil then
    animaItemsLoaded = false

    animaItems = {
        [183727] = 3    -- "Resonance of Conflict"
    }

    WA_ANIMAINBAGS_ANIMAITEMS = animaItems
end

aura_env.cacheAnimaItemInfo = function(itemId)
    -- If the specified 'itemId' is an anima item, try to cache its anima value
    -- into the 'animaItems' map.
    --
    -- Based on https://wago.io/d3T2l8gld/3

    if not C_Item.IsAnimaItemByID(itemId) or itemId == 183727 then
        return
    end

    local quality = select(3, GetItemInfo(itemId))
    local value = nil

    if quality == 2 then        -- green
        value = 5
    elseif quality == 3 then    -- blue
        value = 35
    elseif quality == 4 then     -- purple
        value = 250
    end

    animaItems[itemId] = value
end

if not animaItemsLoaded then
    -- Brute-force all item IDs to construct a map from anima item IDs to their
    -- anima values.  Save the map as a global variable so that we don't do
    -- this on every update to the aura.

    for itemId = 1, 999999 do
        aura_env.cacheAnimaItemInfo(itemId)
    end
end

aura_env.getCurrency = function()
    -- Return the amount of anima the player has as currency.

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(1813)
    if currencyInfo == nil then
        return 0
    end

    return currencyInfo.quantity
end

aura_env.getInInventory = function()
    -- Return the amount of anima in the player's inventory, both excluding and
    -- including the player's bank as the first and second return values,
    -- respectively.

    local inBackpack = 0
    local inBackpackAndBank = 0

    for itemId, animaValue in pairs(animaItems) do
        local count

        count = GetItemCount(itemId, false)     -- exclude bank
        inBackpack = inBackpack + count * animaValue

        count = GetItemCount(itemId, true)      -- include bank
        inBackpackAndBank = inBackpackAndBank + count * animaValue
    end

    return inBackpack, inBackpackAndBank
end

-------------------------------------------------------------------------------
-- trigger (TSU): BAG_UPDATE_DELAYED, CURRENCY_DISPLAY_UPDATE, PLAYERBANKSLOTS_CHANGED, GET_ITEM_INFO_RECEIVED

function(allstates, event, ...)
    if event == 'CURRENCY_DISPLAY_UPDATE' then
        local currencyId, _ = ...
        if currencyId ~= 1813 then
            return false
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemId, success = ...
        if not success then
            return false
        end

        aura_env.cacheAnimaItemInfo(itemId)
    end

    local state = allstates[1]
    if state == nil then
        state = {}
        allstates[1] = state
    end

    state.changed = true
    state.show = true

    state.currency = aura_env.getCurrency()
    state.inBackpack, state.inBackpackAndBank = aura_env.getInInventory()

    -- Calculate derived values.

    state.inBank = state.inBackpackAndBank - state.inBackpack
    state.animaTotal = state.inBackpackAndBank + state.currency

    return true
end

-------------------------------------------------------------------------------
-- custom variables

{
    ["currency"] = "number",
    ["inBackpack"] = "number",
    ["inBackpackAndBank"] = "number",
    ["inBank"] = "number",
    ["animaTotal"] = "number",
}

-------------------------------------------------------------------------------
-- custom anchor

function()
    for i = 1,3 do
        local frame = _G["ElvUI_ContainerFrameCurrencyButton" .. i]
        if frame.currencyID == 1813 then
            return frame
        end
    end
end

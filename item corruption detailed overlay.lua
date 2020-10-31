--[[
TODO:
    - add TSU states for equipment flyout frames (when using the Equipment Manager)
        - flyout frames hold a 'location' element that seem to map (somehow) to 'ItemLocation'
            - research this mapping: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/FrameXML/EquipmentFlyout.lua
                -- apparently allows multiple pages of flyouts
    - support elvui bags
        - is it possible that 'location' element above provides an alternative way to get frame?
            - how does WeakAuras find frames for nameplates and unitframes? https://github.com/WeakAuras/WeakAuras2/blob/master/WeakAurasOptions/RegionOptions/DynamicGroup.lua#L128
]]--

-- On Init
-- NOTE: This implementation intentionally does not support AdiBags because of
-- AdiBags' nonstandard behavior.
--
-- For the version of this WeakAura that supports AdiBags, see instead:
-- https://wago.io/ViiuziT0D

aura_env.corruption = {
    ["6483"] = {"Avoidant", "I", 315607, 8},
    ["6484"] = {"Avoidant", "II", 315608, 12},
    ["6485"] = {"Avoidant", "III", 315609, 16},
    ["6474"] = {"Expedient", "I", 315544, 10},
    ["6475"] = {"Expedient", "II", 315545, 15},
    ["6476"] = {"Expedient", "III", 315546, 20},
    ["6471"] = {"Masterful", "I", 315529, 10},
    ["6472"] = {"Masterful", "II", 315530, 15},
    ["6473"] = {"Masterful", "III", 315531, 20},
    ["6480"] = {"Severe", "I", 315554, 10},
    ["6481"] = {"Severe", "II", 315557, 15},
    ["6482"] = {"Severe", "III", 315558, 20},
    ["6477"] = {"Versatile", "I", 315549, 10},
    ["6478"] = {"Versatile", "II", 315552, 15},
    ["6479"] = {"Versatile", "III", 315553, 20},
    ["6493"] = {"Siphoner", "I", 315590, 17},
    ["6494"] = {"Siphoner", "II", 315591, 28},
    ["6495"] = {"Siphoner", "III", 315592, 45},
    ["6437"] = {"Strikethrough", "I", 315277, 10},
    ["6438"] = {"Strikethrough", "II", 315281, 15},
    ["6439"] = {"Strikethrough", "III", 315282, 20},
    ["6555"] = {"Racing Pulse", "I", 318266, 15},
    ["6559"] = {"Racing Pulse", "II", 318492, 20},
    ["6560"] = {"Racing Pulse", "III", 318496, 35},
    ["6556"] = {"Deadly Momentum", "I", 318268, 15},
    ["6561"] = {"Deadly Momentum", "II", 318493, 20},
    ["6562"] = {"Deadly Momentum", "III", 318497, 35},
    ["6558"] = {"Surging Vitality", "I", 318270, 15},
    ["6565"] = {"Surging Vitality", "II", 318495, 20},
    ["6566"] = {"Surging Vitality", "III", 318499, 35},
    ["6557"] = {"Honed Mind", "I", 318269, 15},
    ["6563"] = {"Honed Mind", "II", 318494, 20},
    ["6564"] = {"Honed Mind", "III", 318498, 35},
    ["6549"] = {"Echoing Void", "I", 318280, 25},
    ["6550"] = {"Echoing Void", "II", 318485, 35},
    ["6551"] = {"Echoing Void", "III", 318486, 60},
    ["6552"] = {"Infinite Stars", "I", 318274, 20},
    ["6553"] = {"Infinite Stars", "II", 318487, 50},
    ["6554"] = {"Infinite Stars", "III", 318488, 75},
    ["6547"] = {"Ineffable Truth", "I", 318303, 12},
    ["6548"] = {"Ineffable Truth", "II", 318484, 30},
    ["6537"] = {"Twilight Devastation", "I", 318276, 25},
    ["6538"] = {"Twilight Devastation", "II", 318477, 50},
    ["6539"] = {"Twilight Devastation", "III", 318478, 75},
    ["6543"] = {"Twisted Appendage", "I", 318481, 10},
    ["6544"] = {"Twisted Appendage", "II", 318482, 35},
    ["6545"] = {"Twisted Appendage", "III", 318483, 66},
    ["6540"] = {"Void Ritual", "I", 318286, 15},
    ["6541"] = {"Void Ritual", "II", 318479, 35},
    ["6542"] = {"Void Ritual", "III", 318480, 66},
    ["6573"] = {"Gushing Wound", "", 318272, 15},
    ["6546"] = {"Glimpse of Clarity", " ", 318239, 15},
    ["6571"] = {"Searing Flames", " ", 318293, 30},
    ["6572"] = {"Obsidian Skin", " ", 316651, 50},
    ["6567"] = {"Devour Vitality", " ", 318294, 35},
    ["6568"] = {"Whispered Truths", " ", 316780, 25},
    ["6570"] = {"Flash of Insight", " ", 318299, 20},
    ["6569"] = {"Lash of the Void", " ", 317290, 25},
}

aura_env.updatingBags = {} -- a set of bag IDs being updated

aura_env.itemLinkPattern = "item:" .. string.rep("[^:]*:", 12) .. "(.*)"
aura_env.getLocationLink = function(location)
    -- Return the item link for the specified 'location'.  If 'location' is
    -- null, return 'nil' instead.

    if location:IsBagAndSlot() then
        return GetContainerItemLink(location:GetBagAndSlot())
    elseif location:IsEquipmentSlot() then
        return GetInventoryItemLink("player", location:GetEquipmentSlot())
    else
        return nil
    end
end

aura_env.isEmptyLink = function(itemLink)
    -- Return 'true' if the specified 'itemLink' is empty.  A link is
    -- considered empty if its display text in chat is the string, "[]".

    return string.find(itemLink, "|h%[]|h|r") ~= nil
end

aura_env.getItemBonuses = function(itemLink)
    -- Return an array of strings (each convertible to an integer) of the
    -- bonuses for the specified 'itemLink'.

    -- Match the pattern against 'itemLink'.  The first colon-delimited field
    -- is the number of following fields that we should process.

    local bonuses = string.match(itemLink, aura_env.itemLinkPattern)
    local numBonuses, bonuses = strsplit(':', bonuses, 2)
    numBonuses = tonumber(numBonuses)
    bonuses = { strsplit(':', bonuses, numBonuses + 1) }
    bonuses[#bonuses] = nil

    return bonuses
end

aura_env.getCorruptionInfo = function(location)
    -- For the item in the specified 'location', return a string for the
    -- corruption bonus name, a string for the corruption bonus rank, an
    -- integer icon path for the corruption bonus, and an integer for the
    -- corruption cost.  If the item in 'location' is not corrupted, return
    -- 'nil' instead.

    local link = aura_env.getLocationLink(location)
    if link ~= nil and aura_env.isEmptyLink(link) then
        -- Schedule for this position to be re-updated again later.

        C_Timer.After(1, function() WeakAuras.ScanEvents("WA_DEFERRED_CORRUPTION_OVERLAY_UPDATE", location) end)
        return nil
    elseif link == nil or not IsCorruptedItem(link) then
        return nil
    end

    local bonuses = aura_env.getItemBonuses(link)
    for i=1,#bonuses do
        local bonus = bonuses[i]
        if bonus ~= "" then
            local corruptionInfo = aura_env.corruption[bonus]
            if corruptionInfo ~= nil then
                -- Return the formatted string for this corruption bonus.

                local iconPath = select(3, GetSpellInfo(corruptionInfo[3]))
                return corruptionInfo[1], corruptionInfo[2], iconPath, corruptionInfo[4]
            end
        end
    end
end

aura_env.updateStateForLocation = function(allstates, location)
    -- Insert, update, or clear the state within the specified 'allstates' for
    -- the specified 'location'.

    local slotFrameName = aura_env.getSlotFrameName(location)
    if slotFrameName ~= nil then
        local name, rank, icon, cost = aura_env.getCorruptionInfo(location)
        local state = allstates[slotFrameName]

        if name ~= nil then
            -- 'location' holds a piece of corrupted gear.  Insert a state into
            -- 'allstates' for 'location'.

            if state == nil then
                state = {}
                allstates[slotFrameName] = state
            end

            state.show = true
            state.corruptionName = name
            state.corruptionRank = rank
            state.corruptionCost = cost
            state.icon = icon
            state.slotFrame = _G[slotFrameName]
            state.changed = true
        elseif state ~= nil then
            -- 'location' does not hold a piece of corrupted gear, but 'state'
            -- points to a valid entry in 'allstates'.  Update it to hide the
            -- corresponding clone.

            state.show = false
            state.changed = true
        end
    end
end

aura_env.getLocationsForBag = function(bagId)
    -- Return an array of all locations within the bag with the specified
    -- 'bagId'.

    local locations = {}
    for slot=1,GetContainerNumSlots(bagId) do
        locations[#locations + 1] = ItemLocation:CreateFromBagAndSlot(bagId, slot)
    end

    return locations
end

aura_env.getLocationsForBank = function()
    -- Return an array of all locations within the primary bank (bag -1) and
    -- within all bank bags (bags 5-11)
    local locations = aura_env.getLocationsForBag(-1)
    for bag=NUM_BAG_SLOTS+1,NUM_BAG_SLOTS+NUM_BANKBAGSLOTS do
        for _,v in pairs(aura_env.getLocationsForBag(bag)) do
            locations[#locations + 1] = v
        end
    end

    return locations
end

aura_env.getLocationsForPlayer = function()
    -- Return an array of all locations on the player character (i.e.,
    -- equipment and non-bank bags).

    local locations = {}
    for bag=0,NUM_BAG_SLOTS do
        for slot=1,GetContainerNumSlots(bag) do
            locations[#locations+1] = ItemLocation:CreateFromBagAndSlot(bag, slot)
        end
    end

    for inventorySlot=1,17 do
        locations[#locations+1] = ItemLocation:CreateFromEquipmentSlot(inventorySlot)
    end

    return locations
end

aura_env.updateStatesForLocations = function(allstates, locations)
    -- Insert, update, or clear the states within the specified 'allstates' for
    -- each 'ItemLocation' mixin object in the specified 'locations'.

    for _,location in pairs(locations) do
        aura_env.updateStateForLocation(allstates, location)
    end
end

aura_env.getBagSlotFrameName_Blizzard = function(bag, slot)
    -- Return the name for the Blizzard 'Frame' element for the specified 'bag'
    -- and 'slot'.  If 'bag' and 'slot' are invalid, return 'nil' instead.

    if bag >= 0 then
        local containerSlots = GetContainerNumSlots(bag)
        return "ContainerFrame" .. (bag + 1) .. "Item" .. (containerSlots - slot + 1)
    elseif bag == -1 then
        return "BankFrameItem" .. slot
    else
        return nil
    end
end

aura_env.getBagSlotFrameName_ElvUI = function(bag, slot)
    -- Return the name for the ElvUI 'Frame' element for the specified 'bag'
    -- and 'slot'.  If 'bag' and 'slot' are invalid, return 'nil' instead.

    if bag >= 0 and bag <= NUM_BAG_SLOTS then
        return "ElvUI_ContainerFrameBag" .. bag .. "Slot" .. slot
    elseif bag == -1 or bag > NUM_BAG_SLOTS then
        return "ElvUI_BankContainerFrameBag" .. bag .. "Slot" .. slot
    else
        return nil
    end
end

aura_env.getSlotFrameName = function(location)
    -- Return the name for the 'Frame' UI element for the specified 'location'.
    -- If 'location' is not valid, return 'nil' instead.  Note that these frame
    -- names will differ across addons (e.g., bag addons), and this function
    -- will need to be specialized for those addons.

    if location:IsBagAndSlot() then
        local bag, slot = location:GetBagAndSlot()
        if ElvUI_ContainerFrame ~= nil then
            return aura_env.getBagSlotFrameName_ElvUI(bag, slot)
        else
            return aura_env.getBagSlotFrameName_Blizzard(bag, slot)
        end
    elseif location:IsEquipmentSlot() then
        local slotIndex = location:GetEquipmentSlot()
        local slotName

        -- Note that we check only the inventory slots for which gear can
        -- corrupt.

        if slotIndex == 9 then slotName = "Wrist"
        elseif slotIndex == 10 then slotName = "Hands"
        elseif slotIndex == 6 then slotName = "Waist"
        elseif slotIndex == 7 then slotName = "Legs"
        elseif slotIndex == 8 then slotName = "Feet"
        elseif slotIndex == 11 then slotName = "Finger0"
        elseif slotIndex == 12 then slotName = "Finger1"
        elseif slotIndex == 16 then slotName = "MainHand"
        elseif slotIndex == 17 then slotName = "SecondaryHand"
        else return nil
        end

        return "Character" .. slotName .. "Slot"
    else
        return nil
    end
end

-- Custom Anchor
function()
    if aura_env.state then
        return aura_env.state.slotFrame
    end
end

-- Trigger on: BAG_UPDATE, BAG_UPDATE_DELAYED, PLAYERBANKSLOTS_CHANGED, PLAYER_EQUIPMENT_CHANGED, BANKFRAME_OPENED, dummy, WA_DEFERRED_CORRUPTION_OVERLAY_UPDATE
function(allstates, event, arg1)
    if event == "BAG_UPDATE" then
        -- This event is fired each bag (i.e., bags 0-11, not including the
        -- main bank bag) that is affected by an item move.

        if arg1 == nil then
            return false
        end

        aura_env.updatingBags[arg1] = true

        return false
    elseif event == "BAG_UPDATE_DELAYED" then
        -- This event is fired whenever the changes for the queued 'BAG_UPDATE'
        -- events are done.

        for bag,_ in pairs(aura_env.updatingBags) do
            local locations = aura_env.getLocationsForBag(bag)
            aura_env.updateStatesForLocations(allstates, locations)
            aura_env.updatingBags[bag] = nil
        end

        return true
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        -- This event is fired for each slot in the primary bank (bag -1)
        -- that is changed.

        if arg1 == nil then
            return false
        end

        local location = ItemLocation:CreateFromBagAndSlot(-1, arg1)
        aura_env.updateStateForLocation(allstates, location)
        return true
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- This event is fired for each equipment slot that is changed.

        if arg1 == nil then
            return false
        end

        local location = ItemLocation:CreateFromEquipmentSlot(arg1)
        aura_env.updateStateForLocation(allstates, location)
        return true
    elseif event == "BANKFRAME_OPENED" then
        -- This event is fired when the player opens the bank.

        local locations = aura_env.getLocationsForBank()
        aura_env.updateStatesForLocations(allstates, locations)
        return true
    elseif event == "WA_DEFERRED_CORRUPTION_OVERLAY_UPDATE" then
        -- This event is fired after a timer for each location for which this
        -- aura fails to get a valid item link.  'arg1' is an 'ItemLocation'.

        if arg1 == nil then
            return false
        end

        aura_env.updateStateForLocation(allstates, arg1)
        return true
    else -- "OPTIONS" or "dummy"
        -- This WeakAura is being initialized or reconfigured.

        local locations = aura_env.getLocationsForPlayer()
        aura_env.updateStatesForLocations(allstates, locations)
        return true
    end
end
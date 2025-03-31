local addonName, ns = ...
local AuctionHouse = ns.AuctionHouse

local TradeAPI = {}
ns.TradeAPI = TradeAPI

function TradeAPI:OnInitialize()
    -- Create event frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Register events
    self.eventFrame:RegisterEvent("MAIL_SHOW")
    self.eventFrame:RegisterEvent("MAIL_CLOSED")
    self.eventFrame:RegisterEvent("UI_INFO_MESSAGE") 
    self.eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
    self.eventFrame:RegisterEvent("TRADE_SHOW")
    self.eventFrame:RegisterEvent("TRADE_MONEY_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")

    -- Create a separate frame for secure trade operations
    self.tradeFrame = CreateFrame("Frame")
    self.tradeFrame:SetScript("OnEvent", function(_, event)
        local targetName = GetUnitName("NPC", true)
        if event == "TRADE_SHOW" and targetName then
            -- Delay slightly, workaround for items sometimes not getting tracked
            C_Timer.After(1, function()
                self:TryPrefillTradeWindow(targetName)
            end)
        end
    end)
    self.tradeFrame:RegisterEvent("TRADE_SHOW")
end

local function CreateNewTrade()
    return {
        tradeId = nil,
        playerName = UnitName("player"),
        targetName = nil,
        playerMoney = 0,
        targetMoney = 0,
        playerItems = {},
        targetItems = {},
    }
end

CURRENT_TRADE = nil

local function CurrentTrade()
    if (not CURRENT_TRADE) then
        CURRENT_TRADE = CreateNewTrade()
    end
    return CURRENT_TRADE
end

local function Reset(source)
    ns.DebugLog("[DEBUG] Reset Trade " .. (source or ""))
    CURRENT_TRADE = nil
end

-- this function leaks memory on cache miss because of CreateFrame
--
-- we have to use though, because Item:CreateItemFromItemID doesn't work here (we have a name, not itemID)
-- not called often (on trade when someone puts in a previously unknown item), so should be fine
local function GetItemInfoAsyncWithMemoryLeak(itemName, callback)
    local name = GetItemInfo(itemName)
    if name then
        callback(GetItemInfo(itemName))
    else
        local frame = CreateFrame("FRAME")
        frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        frame:SetScript("OnEvent", function(self, event, ...)
            callback(GetItemInfo(itemName))
            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        end)
    end
end

local function UpdateItemInfo(id, unit, items)
    local funcInfo = getglobal("GetTrade" .. unit .. "ItemInfo")

    local name, texture, numItems, quality, isUsable, enchantment
    if (unit == "Target") then
        name, texture, numItems, quality, isUsable, enchantment = funcInfo(id)
    else
        name, texture, numItems, quality, enchantment = funcInfo(id)
    end

    if (not name) then
        items[id] = nil
        return
    end

    -- GetTradePlayerItemInfo annoyingly doesn't return the itemID, and there's not obvious way to get the itemID from a trade
    -- in most cases itemID will be available instantly, so race conditions shouldn't be too common
    GetItemInfoAsyncWithMemoryLeak(name, function (_, itemLink)
        local itemID = tonumber(itemLink:match("item:(%d+):"))

        items[id] = {
            itemID = itemID,
            name = name,
            numItems = numItems,
        }
    end)
end

local function UpdateMoney()
    CurrentTrade().playerMoney = GetPlayerTradeMoney()
    CurrentTrade().targetMoney = GetTargetTradeMoney()
end

local function HandleTradeOK()
    local t = CurrentTrade()

    -- Get the items that were traded
    --
    -- both the buyer and seller mark the trade as 'complete',
    -- they always should come to the same conclusion (so conflicting network updates shouldn't arise)
    local playerItems = {}
    local targetItems = {}
    for _, item in pairs(t.playerItems) do
        table.insert(playerItems, {
            itemID = item.itemID,
            count = item.numItems
        })
    end
    for _, item in pairs(t.targetItems) do
        table.insert(targetItems, {
            itemID = item.itemID,
            count = item.numItems
        })
    end

    if #playerItems == 0 and #targetItems == 0 then
        -- insert gold as fake item only if no other items are being traded
        if t.playerMoney then
            table.insert(playerItems, {
                itemID = ns.ITEM_ID_GOLD,
                count = t.playerMoney
            })
        end
        if t.targetMoney then
            table.insert(targetItems, {
                itemID = ns.ITEM_ID_GOLD,
                count = t.targetMoney
            })
        end
    end

    -- Debug prints for items
    for i, item in pairs(t.playerItems) do
        ns.DebugLog("[DEBUG] HandleTradeOK Player Item", i, ":", item.itemID, "x", item.numItems)
    end
    for i, item in pairs(t.targetItems) do
        ns.DebugLog("[DEBUG] HandleTradeOK Target Item", i, ":", item.itemID, "x", item.numItems)
    end
    ns.DebugLog(
        "[DEBUG] HandleTradeOK",
        t.playerName, t.targetName,
        t.playerMoney, t.targetMoney,
        #playerItems, #targetItems
    )

    local function tryMatch(seller, buyer, items, money)
        local success, hadCandidates, err, trade = ns.AuctionHouseAPI:TryCompleteItemTransfer(
            seller,
            buyer,
            items,
            money,
            ns.DELIVERY_TYPE_TRADE
        )

        if success and trade then
            StaticPopup_Show("OF_LEAVE_REVIEW", nil, nil, { tradeID = trade.id })
            return true, nil
        elseif err and hadCandidates then
            local itemInfo = ""
            if playerItems[1] then
                itemInfo = itemInfo .. " (Player: " .. playerItems[1].itemID .. " x" .. playerItems[1].count .. ")"
            end
            if targetItems[1] then
                itemInfo = itemInfo .. " (Target: " .. targetItems[1].itemID .. " x" .. targetItems[1].count .. ")"
            end

            local msg
            if err == "No matching auction found" then
                msg = " Trade didn't match any guild auctions" .. itemInfo
            else
                msg = " Trade didn't match any guild auctions: " .. err .. itemInfo
            end

            return false, msg
        end
        return false
    end

    -- Try first direction (target as seller)
    local success, message1 = tryMatch(t.targetName, t.playerName, targetItems, t.playerMoney or 0)
    local message2

    -- If first attempt failed, try reverse direction
    if not success then
        _, message2 = tryMatch(t.playerName, t.targetName, playerItems, t.targetMoney or 0)
    end

    -- Print message if we got one
    if message1 then
        print(ChatPrefix() .. message1)
    elseif message2 then
        print(ChatPrefix() .. message2)
    end
    Reset("HandleTradeOK")
end

-- Single event handler function
function TradeAPI:OnEvent(event, ...)
    if event == "MAIL_SHOW" then
        -- print("[DEBUG] MAIL_SHOW")

    elseif event == "MAIL_CLOSED" then
        -- print("[DEBUG] MAIL_CLOSED")

    elseif event == "UI_ERROR_MESSAGE" then
        local _, arg2 = ...
        if (arg2 == ERR_TRADE_BAG_FULL or
            arg2 == ERR_TRADE_TARGET_BAG_FULL or
            arg2 == ERR_TRADE_MAX_COUNT_EXCEEDED or
            arg2 == ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED or
            arg2 == ERR_TRADE_TARGET_DEAD or
            arg2 == ERR_TRADE_TOO_FAR) then
            -- print("[DEBUG] Trade failed")
            Reset("trade failed "..arg2)  -- trade failed
        end

    elseif event == "UI_INFO_MESSAGE" then
        local _, arg2 = ...
        if (arg2 == ERR_TRADE_CANCELLED) then
            -- print("[DEBUG] Trade cancelled")
            Reset("trade cancelled")
        elseif (arg2 == ERR_TRADE_COMPLETE) then
            HandleTradeOK()
        end

    elseif event == "TRADE_SHOW" then
        CurrentTrade().targetName = GetUnitName("NPC", true)

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        local arg1 = ...
        UpdateItemInfo(arg1, "Player", CurrentTrade().playerItems)
        ns.DebugLog("[DEBUG] Player ITEM_CHANGED", arg1)

    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        local arg1 = ...
        UpdateItemInfo(arg1, "Target", CurrentTrade().targetItems)
        ns.DebugLog("[DEBUG] Target ITEM_CHANGED", arg1)

    elseif event == "TRADE_MONEY_CHANGED" then
        UpdateMoney()
        -- print("[DEBUG] TRADE_MONEY_CHANGED")

    elseif event == "TRADE_ACCEPT_UPDATE" then
        for i = 1, 7 do
            UpdateItemInfo(i, "Player", CurrentTrade().playerItems)
            UpdateItemInfo(i, "Target", CurrentTrade().targetItems)
        end
        UpdateMoney()
        -- print("[DEBUG] TRADE_ACCEPT_UPDATE")
    end
end

-- findMatchingAuction picks the last-created auction that involves 'me' and targetName
-- we pick the last-created auction so both parties agree on which one should be prefilled
local function findMatchingAuction(myPendingAsSeller, myPendingAsBuyer, targetName)
    local bestMatch = nil
    local isSeller = false

    -- Check if I'm the seller and the partner is the buyer
    for _, auction in ipairs(myPendingAsSeller) do
        if auction.buyer == targetName then
            if not bestMatch or auction.createdAt > bestMatch.createdAt then
                bestMatch = auction
                isSeller = true
            end
        end
    end

    -- Check if I'm the buyer and the partner is the seller
    for _, auction in ipairs(myPendingAsBuyer) do
        if auction.owner == targetName then
            if not bestMatch or auction.createdAt > bestMatch.createdAt then
                bestMatch = auction
                isSeller = false
            end
        end
    end

    return bestMatch, isSeller
end

function TradeAPI:PrefillGold(relevantAuction, totalPrice, targetName)
    -- I'm the buyer: prefill the gold amount
    if totalPrice > 0 and relevantAuction.status ~= ns.AUCTION_STATUS_PENDING_LOAN
        and relevantAuction.status ~= ns.AUCTION_STATUS_SENT_LOAN then
        local playerMoney = GetMoney()

        if playerMoney >= totalPrice then
            -- NOTE: not using SetTrademoney because that one doesn't update the UI properly
            -- see https://www.reddit.com/r/classicwow/comments/hfp1nm/comment/izsvq5c/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
            MoneyInputFrame_SetCopper(TradePlayerInputMoneyFrame, totalPrice)

            -- success message
            print(ChatPrefix() .. " Auto-filled trade with " .. GetCoinTextureString(totalPrice) ..
                    " for auction from " .. targetName)
        else
            print(ChatPrefixError() .. " You don't have enough gold to complete this trade. "
                .. "The auction costs " .. GetCoinTextureString(totalPrice) .. "")
        end
    end
end

function TradeAPI:PrefillItem(itemID, quantity, targetName)
    -- I'm the owner: prefill trade with the item
    -- Use new helper function to find the item
    local bag, slot, exactMatch = self:FindBestMatchForTrade(itemID, quantity)
    if slot and exactMatch then
        -- select item
        C_Container.PickupContainerItem(bag, slot)

        -- place it into the first trade slot
        ClickTradeButton(1)
        -- success message
        local name, itemLink = ns.GetItemInfo(itemID, quantity)
        local itemDescription
        if itemID == ns.ITEM_ID_GOLD then
            itemDescription = name
        else
            itemLink = itemLink or "item"
            itemDescription = quantity .. "x " .. itemLink
        end
        print(ChatPrefix() .. " Auto-filled trade with " ..
                itemDescription .. " for auction to " .. targetName)
    else
        -- error message when item not found or quantity doesn't match exactly
        local itemName = select(2, ns.GetItemInfo(itemID)) or "item"
        local errorMsg = not slot and
            " Could not find " .. quantity .. "x " .. itemName .. " in your bags for the trade"
            or
            " Found the item but stack size doesn't match exactly. Please manually split a stack of " .. quantity .. " " .. itemName
        print(ChatPrefixError() .. errorMsg)
    end
end

function TradeAPI:TryPrefillTradeWindow(targetName)
    if not targetName or targetName == "" then
        return
    end

    local me = UnitName("player")
    if me == targetName then
        return
    end

    local AuctionHouseAPI = ns.AuctionHouseAPI

    -- 1. Gather potential auctions where I'm the seller or the buyer and the status is pending trade
    local myPendingAsSeller = AuctionHouseAPI:GetAuctionsWithOwnerAndStatus(me, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })
    local myPendingAsBuyer  = AuctionHouseAPI:GetAuctionsWithBuyerAndStatus(me, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })

    local function filterAuctions(auctions)
        local filtered = {}
        for _, auction in ipairs(auctions) do
            -- Filter out mail delivery auctions and death roll (we don't prefill those)
            local deliveryMatch = auction.deliveryType ~= ns.DELIVERY_TYPE_MAIL
            local excluded = auction.deathRoll or auction.duel

            if deliveryMatch and not excluded then
                table.insert(filtered, auction)
            end
        end
        return filtered
    end

    -- Apply filters
    myPendingAsSeller = filterAuctions(myPendingAsSeller)
    myPendingAsBuyer = filterAuctions(myPendingAsBuyer)

    -- 2. Attempt to find an auction that matches the current trade partner
    local relevantAuction, isSeller = findMatchingAuction(myPendingAsSeller, myPendingAsBuyer, targetName)

    if not relevantAuction then
        -- No matching auction
        return
    end

    local itemID = relevantAuction.itemID
    local quantity = relevantAuction.quantity or 1
    local totalPrice = (relevantAuction.price or 0) + (relevantAuction.tip or 0)

    if ns.IsUnsupportedFakeItem(itemID) then
        print(ChatPrefix() .. " Unknown Item when trading with " .. targetName .. ". Update to the latest version to trade this item")
        return
    end

    if isSeller then
        if itemID == ns.ITEM_ID_GOLD then
            -- NOTE: here, quantity is the amount of copper
            self:PrefillGold(relevantAuction, quantity, targetName)
        else
            self:PrefillItem(itemID, quantity, targetName)
        end
    else
        -- NOTE: for ITEM_ID_GOLD totalPrice is expected to be 0
        -- But maybe we'll support for tips or other weirdness later on, so just handle what's on the auction
        self:PrefillGold(relevantAuction, totalPrice, targetName)
    end
end

local function FindItemInBags(itemID, quantity, matchQuantityExact)
    local bestMatch = {
        bag = nil,
        slot = nil,
        count = 0
    }

    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local count = itemInfo.stackCount
                local link = itemInfo.hyperlink
                local bagItemID = tonumber(link:match("item:(%d+):"))

                if bagItemID == itemID then
                    if matchQuantityExact then
                        if count == quantity then
                            return bag, slot
                        end
                    else
                        -- Find the stack that's closest to (but not less than) the desired quantity
                        if count >= quantity and (bestMatch.count == 0 or count < bestMatch.count) then
                            bestMatch.bag = bag
                            bestMatch.slot = slot
                            bestMatch.count = count
                        end
                    end
                end
            end
        end
    end

    return bestMatch.bag, bestMatch.slot
end

function TradeAPI:FindBestMatchForTrade(itemID, quantity)
    -- First try to find an exact quantity match
    local bag, slot = FindItemInBags(itemID, quantity, true)

    if slot then
        -- Exact match found
        return bag, slot, true
    end

    -- Look for any stack large enough
    bag, slot = FindItemInBags(itemID, quantity, false)

    -- Return bag, slot, and false to indicate inexact match
    return bag, slot, false
end

local addonName, ns = ...

local TradeAPI = {}
ns.TradeAPI = TradeAPI

function TradeAPI:OnInitialize()
    -- Create event frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Add trade show timestamp tracking
    self.lastTradeShowTime = 0

    -- Initialize the state locking flag <<< ADD THIS LINE >>>
    self.isTradeFinalizing = false

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
            C_Timer:After(1, function()
                -- Ensure TryPrefillTradeWindow exists on self if called like this
                if self.TryPrefillTradeWindow then
                    self:TryPrefillTradeWindow(targetName)
                end
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
        ns.DebugLog("[DEBUG] HandleTradeOK Player Item", i, ":", item.itemID, "x", item.count)
    end
    for i, item in pairs(t.targetItems) do
        ns.DebugLog("[DEBUG] HandleTradeOK Target Item", i, ":", item.itemID, "x", item.count)
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

            -- success, subtract points
            if trade.auction.priceType == ns.PRICE_TYPE_GUILD_POINTS then
                local tx, err = ns.PendingTxAPI:AddPendingTransaction({
                    type = ns.PRICE_TYPE_GUILD_POINTS,
                    amount = trade.auction.points,
                    from = trade.auction.buyer,
                    to = trade.auction.owner,
                    id = trade.auction.id,
                })
                if tx then
                    -- immediately handle locally for fast/correct apply
                    ns.PendingTxAPI:HandlePendingTransactionChange(tx)
                else
                    print(ChatPrefixError() .. L[" Failed to transfer points:"], err)
                    -- NOTE: error here should not happen and will mean points aren't correctly charged.
                    -- we can't easily recover to a better state
                    return
                end
            end

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
        -- Original logic (potentially includes Reset)
        -- If original Reset was called here, the flag needs manual reset too
        if self.isTradeFinalizing then self.isTradeFinalizing = false end -- Reset flag if needed

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
            -- Original logic (likely called Reset)
            Reset("trade failed error: " .. arg2) -- Call original Reset
            self.isTradeFinalizing = false        -- <<< Manually reset flag >>>
        end

    elseif event == "UI_INFO_MESSAGE" then
        local arg1, arg2 = ...
        if (arg1 == ERR_TRADE_CANCELLED) then
            -- Original logic (likely called Reset and printed messages)
            local timeSinceShow = GetTime() - (self.lastTradeShowTime or 0)
            if timeSinceShow < 0.5 then
                print(ChatPrefixError() .. L[" The Go Again addon requires that both players target each other before starting a trade."])
            end
            Reset("trade cancelled")          -- Call original Reset
            self.isTradeFinalizing = false    -- <<< Manually reset flag >>>

        elseif (arg1 == ERR_TRADE_COMPLETE) then
            -- Trade completed successfully
            -- Call original HandleTradeOK. It operates on the state frozen by TRADE_ACCEPT_UPDATE.
            HandleTradeOK()                   -- Call original HandleTradeOK
            -- Assume original HandleTradeOK calls Reset internally OR we reset here
            self.isTradeFinalizing = false    -- <<< Manually reset flag AFTER HandleTradeOK >>>
            -- If HandleTradeOK doesn't call Reset, you might need Reset("TRADE_COMPLETE") here too.
        end

    elseif event == "TRADE_SHOW" then
        -- Original logic (likely called Reset and set targetName/time)
        Reset("TRADE_SHOW")               -- Call original Reset
        self.isTradeFinalizing = false    -- <<< Manually reset flag >>>
        CurrentTrade().targetName = GetUnitName("NPC", true)
        self.lastTradeShowTime = GetTime()

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        if self.isTradeFinalizing then return end -- <<< ADD GUARD: Check flag >>>
        -- Original logic below
        local arg1 = ...
        UpdateItemInfo(arg1, "Player", CurrentTrade().playerItems)
        ns.DebugLog("[DEBUG] Player ITEM_CHANGED", arg1)

    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        if self.isTradeFinalizing then return end -- <<< ADD GUARD: Check flag >>>
        -- Original logic below
        local arg1 = ...
        UpdateItemInfo(arg1, "Target", CurrentTrade().targetItems)
        ns.DebugLog("[DEBUG] Target ITEM_CHANGED", arg1)

    elseif event == "TRADE_MONEY_CHANGED" then
        if self.isTradeFinalizing then return end -- <<< ADD GUARD: Check flag >>>
        -- Original logic below
        UpdateMoney()
        -- Original print("[DEBUG] TRADE_MONEY_CHANGED")

    elseif event == "TRADE_ACCEPT_UPDATE" then
        -- Prevent redundant runs if event fires multiple times
        if self.isTradeFinalizing then return end -- <<< ADD GUARD: Check flag >>>

        -- Set the flag to lock the state *before* the final update
        self.isTradeFinalizing = true        -- <<< SET FLAG >>>
        -- Optional: print("Trade state finalizing...")

        -- Perform one last data update *right now* using original functions
        local trade = CurrentTrade()
        if not trade then self.isTradeFinalizing = false; Reset("Error - nil trade on accept update"); return end
        for i = 1, 7 do -- Adjust slot count if needed
            UpdateItemInfo(i, "Player", trade.playerItems)
            UpdateItemInfo(i, "Target", trade.targetItems)
        end
        UpdateMoney()
        -- print("[DEBUG] TRADE_ACCEPT_UPDATE")
    end -- End of event type checks
end -- End of TradeAPI:OnEvent

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
            print(ChatPrefix() .. L[" Auto-filled trade with "] .. GetCoinTextureString(totalPrice) ..
                    L[" for auction from "] .. targetName)
        else
            print(ChatPrefixError() .. L[" You don't have enough gold to complete this trade. "] ..
                L["The auction costs "] .. GetCoinTextureString(totalPrice))
        end
    end
end

function TradeAPI:PrefillItem(itemID, quantity, targetName)
    -- I'm the owner: prefill trade with the item
    -- Use new helper function to find the item
    local bag, slot, exactMatch = self:FindBestMatchForTrade(itemID, quantity)
    if slot and exactMatch then
        -- select item
        PickupContainerItem(bag, slot)

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
        print(ChatPrefix() .. L[" Auto-filled trade with "] ..
                itemDescription .. L[" for auction to "] .. targetName)
    else
        -- error message when item not found or quantity doesn't match exactly
        local itemName = select(2, ns.GetItemInfo(itemID)) or "item"
        local errorMsg = not slot and
            L[" Could not find "] .. quantity .. "x " .. itemName .. L[" in your bags for the trade"]
            or
            L[" Found the item but stack size doesn't match exactly. Please manually split a stack of "] .. quantity .. " " .. itemName
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
        print(ChatPrefix() .. L[" Unknown Item when trading with "] .. targetName .. L[". Update to the latest version to trade this item"])
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
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable = GetContainerItemInfo(bag, slot)
            if texture then
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local bagItemID = tonumber(link:match("item:(%d+):"))
                    if bagItemID == itemID then
                        if matchQuantityExact then
                            if itemCount == quantity then
                                return bag, slot
                            end
                        else
                            -- Find the stack that's closest to (but not less than) the desired quantity
                            if itemCount >= quantity and (bestMatch.count == 0 or itemCount < bestMatch.count) then
                                bestMatch.bag = bag
                                bestMatch.slot = slot
                                bestMatch.count = itemCount
                            end
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

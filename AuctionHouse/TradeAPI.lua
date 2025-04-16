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
-- this function leaks memory on cache miss because of CreateFrame
-- we have to use though, because Item:CreateItemFromItemID doesn't work here (we have a name, not itemID)
-- not called often (on trade when someone puts in a previously unknown item), so should be fine
local function GetItemInfoAsyncWithMemoryLeak(itemName, callback, id) -- Added 'id' parameter
    local itemNameResult, itemLink = GetItemInfo(itemName)
    if itemNameResult then
        if id == 1 then -- Check if slot is 1 before printing
            print("[DEBUG] GetItemInfo ready immediately:", itemName)
        end
        callback(itemNameResult, itemLink)
    else
        if id == 1 then -- Check if slot is 1 before printing
            print("[DEBUG] Waiting for item info:", itemName)
        end
        local frame = CreateFrame("FRAME")
        frame:RegisterCustomEvent("GET_ITEM_INFO_RECEIVED");
        frame:SetScript("OnEvent", function(self, event, ...)
            -- Decide if you want this event print conditional too
            -- if id == 1 then print(event) end
            local nameResult, link = GetItemInfo(itemName)
            if nameResult then
                if id == 1 then -- Check if slot is 1 before printing
                    print("[DEBUG] Received item info:", itemName)
                end
                callback(nameResult, link)
                self:UnregisterCustomEvent("GET_ITEM_INFO_RECEIVED")
                -- The frame still leaks, this doesn't fix the leak itself.
            end
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

    if not name then
        -- Only print if it's slot 1, but always clear the item entry
        if id == 1 then
            print(string.format("[DEBUG] No item name at slot %d for unit %s", id, unit))
        end
        items[id] = nil
        return
    end

    -- Only print if it's slot 1
    if id == 1 then
        print(string.format("[DEBUG] Found trade item slot %d for %s: %s x%d", id, unit, name, numItems or 1))
    end

    -- Call the async function, passing the 'id' along
    GetItemInfoAsyncWithMemoryLeak(name, function(itemNameResult, itemLink)
        -- This callback function now executes potentially later.
        -- It still needs to check the 'id' for its *own* prints.
        if not itemLink then
            if id == 1 then -- Check id before printing inside the callback
                print("[DEBUG] itemLink is nil for", itemNameResult)
            end
            items[id] = nil -- Still update state regardless of print
            return
        end

        local itemID = tonumber(itemLink:match("item:(%d+):"))
        if not itemID then
            if id == 1 then -- Check id before printing inside the callback
                print("[DEBUG] Failed to extract itemID from link:", itemLink)
            end
            -- Keep the item name even if ID extraction fails
            items[id] = {
                itemID = nil,
                name = itemNameResult,
                numItems = numItems,
            }
            if id == 1 then -- Check id before printing inside the callback
                print(string.format("[DEBUG] Stored item (no ID): name=%s, count=%d", itemNameResult, numItems or 1))
            end
            return
        end

        -- Always update the item info in the table
        items[id] = {
            itemID = itemID,
            name = itemNameResult,
            numItems = numItems,
        }

        -- Only print the stored item info if it's slot 1
        if id == 1 then
            print(string.format("[DEBUG] Stored item: id=%d, name=%s, count=%d", itemID or -1, itemNameResult, numItems or 1))
        end
    end, id) -- Pass the 'id' to GetItemInfoAsyncWithMemoryLeak
end


local function UpdateMoney()
    CurrentTrade().playerMoney = GetPlayerTradeMoney()
    CurrentTrade().targetMoney = GetTargetTradeMoney()
end

-- No changes needed in UpdateItemInfo or GetItemInfoAsyncWithMemoryLeak for this fix
-- No changes needed in the event handler section (OnEvent)

local function HandleTradeOK()
    -- print("[DEBUG] HandleTradeOK triggered") -- Optional: Add entry log

    -- *** Start: Fetch final state synchronously ***
    local finalState = {
        playerName = UnitName("player"),
        targetName = GetUnitName("target", true), -- Get target name again just in case
        playerMoney = GetPlayerTradeMoney(),
        targetMoney = GetTargetTradeMoney(),
        playerItems = {}, -- Use temporary tables, indexed by slot
        targetItems = {}, -- Use temporary tables, indexed by slot
    }

    if not finalState.targetName then
        print(ChatPrefixError() .. " Failed to get target name in HandleTradeOK.")
        Reset("HandleTradeOK - No Target")
        return
    end

    -- Loop through all trade slots
    for i = 1, 7 do -- Use NUM_TRADE_SLOTS (usually 7)
        -- Player items
        local pName, _, pNumItems = GetTradePlayerItemInfo(i)
        if pName then
            local _, pItemLink = GetItemInfo(pName) -- Try to get link (might be cached now)
            local pItemID = pItemLink and tonumber(pItemLink:match("item:(%d+):")) or nil
            if pItemID then
                finalState.playerItems[i] = {
                    itemID = pItemID,
                    name = pName,
                    numItems = pNumItems
                }
            else
                -- Handle case where item ID couldn't be fetched synchronously
                print(ChatPrefixError() .. string.format("Could not get ItemID for player item '%s' in slot %d at trade completion.", pName, i))
                finalState.playerItems[i] = { itemID = nil, name = pName, numItems = pNumItems } -- Store with nil ID maybe? Or skip? Let's store for now.
            end
        end

        -- Target items
        local tName, _, tNumItems = GetTradeTargetItemInfo(i)
        if tName then
            local _, tItemLink = GetItemInfo(tName) -- Try to get link (might be cached now)
            local tItemID = tItemLink and tonumber(tItemLink:match("item:(%d+):")) or nil
            if tItemID then
                finalState.targetItems[i] = {
                    itemID = tItemID,
                    name = tName,
                    numItems = tNumItems
                }
            else
                -- Handle case where item ID couldn't be fetched synchronously
                print(ChatPrefixError() .. string.format("Could not get ItemID for target item '%s' in slot %d at trade completion.", tName, i))
                finalState.targetItems[i] = { itemID = nil, name = tName, numItems = tNumItems } -- Store with nil ID
            end
        end
    end
    -- *** End: Fetch final state synchronously ***


    -- Use the 'finalState' table from now on, instead of CurrentTrade()
    local t = finalState -- Assign to 't' for consistency with the rest of the original function

    -- Optional: Debug print the fetched final state
    local function DebugPrintFinalState()
        print("[DEBUG] Final Fetched Trade State:")
        print("  Player:", t.playerName, "| Target:", t.targetName or "nil")
        print("  Player Money:", t.playerMoney or 0, "| Target Money:", t.targetMoney or 0)

        print("  Player Items:")
        local hasPlayerItems = false
        for slot, item in pairs(t.playerItems or {}) do
            if item then
                print(string.format("    [Slot %d] itemID: %s, Name: %s, Count: %s",
                        slot, tostring(item.itemID or "N/A"), item.name or "?", tostring(item.numItems or "?")))
                hasPlayerItems = true
            end
        end
        if not hasPlayerItems then print("    (None)") end

        print("  Target Items:")
        local hasTargetItems = false
        for slot, item in pairs(t.targetItems or {}) do
            if item then
                print(string.format("    [Slot %d] itemID: %s, Name: %s, Count: %s",
                        slot, tostring(item.itemID or "N/A"), item.name or "?", tostring(item.numItems or "?")))
                hasTargetItems = true
            end
        end
        if not hasTargetItems then print("    (None)") end
    end
    DebugPrintFinalState() -- Call the debug print


    -- Get the items that were traded (using the final fetched state 't')
    local playerItemsArray = {}
    local targetItemsArray = {}
    local hasRealPlayerItem = false
    local hasRealTargetItem = false

    for _, item in pairs(t.playerItems) do
        if item and item.itemID then -- Ensure item and itemID exist
            table.insert(playerItemsArray, {
                itemID = item.itemID,
                count = item.numItems
            })
            hasRealPlayerItem = true
        elseif item then
            print(ChatPrefixError().." Player item had no ID in final processing: "..item.name)
        end
    end
    for _, item in pairs(t.targetItems) do
        if item and item.itemID then -- Ensure item and itemID exist
            table.insert(targetItemsArray, {
                itemID = item.itemID,
                count = item.numItems
            })
            hasRealTargetItem = true
        elseif item then
            print(ChatPrefixError().." Target item had no ID in final processing: "..item.name)
        end
    end

    -- Insert gold as fake item only if no other *real* items are being traded by that side
    if not hasRealPlayerItem and t.playerMoney > 0 then
        table.insert(playerItemsArray, {
            itemID = ns.ITEM_ID_GOLD,
            count = t.playerMoney
        })
    end
    if not hasRealTargetItem and t.targetMoney > 0 then
        table.insert(targetItemsArray, {
            itemID = ns.ITEM_ID_GOLD,
            count = t.targetMoney
        })
    end

    -- Debug prints for the arrays being passed to tryMatch
    -- (Keep these concise)
    local playerItemStr = ""
    for _, pItem in ipairs(playerItemsArray) do playerItemStr = playerItemStr .. string.format(" [%d x%d]", pItem.itemID, pItem.count) end
    local targetItemStr = ""
    for _, tItem in ipairs(targetItemsArray) do targetItemStr = targetItemStr .. string.format(" [%d x%d]", tItem.itemID, tItem.count) end
    ns.DebugLog(string.format("[DEBUG] Attempting Match: P:%s T:%s | P Items:%s | T Items:%s | P Money: %d | T Money: %d",
            t.playerName, t.targetName, playerItemStr, targetItemStr, t.playerMoney, t.targetMoney))


    local function tryMatch(seller, buyer, items, money)
        -- Make sure 'items' has at least one entry if matching is expected
        if #items == 0 and money == 0 then
            ns.DebugLog("[DEBUG] tryMatch skipped: Seller offering nothing.")
            return false, false, "Seller offering nothing" -- No success, no candidates (trivial case), reason
        end

        -- Make sure itemIDs are valid before calling
        for _, item in ipairs(items) do
            if not item.itemID then
                ns.DebugLog("[DEBUG] tryMatch aborted: Invalid itemID found in seller items.")
                return false, false, "Invalid itemID detected" -- No success, no candidates, reason
            end
        end

        ns.DebugLog(string.format("[DEBUG] Calling AuctionHouseAPI:TryCompleteItemTransfer | Seller: %s, Buyer: %s, Money: %d, Items: %s",
                seller, buyer, money, playerItemStr)) -- Re-using playerItemStr for brevity, context implies seller's items

        local success, hadCandidates, err, trade = ns.AuctionHouseAPI:TryCompleteItemTransfer(
                seller,
                buyer,
                items, -- Seller's items
                money, -- Buyer's money contribution
                ns.DELIVERY_TYPE_TRADE
        )

        -- (Rest of the tryMatch logic remains the same: StaticPopup, points transfer, return values)
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
                    return false, "Point transfer failed: "..tostring(err) -- Indicate failure reason
                end
            end

            return true, nil -- Success, no error message needed
        elseif err and hadCandidates then
            -- Construct a more informative error message
            local itemInfoSeller = ""
            for i, item in ipairs(items) do itemInfoSeller = itemInfoSeller .. string.format(" [%s x%d]", item.itemID, item.count) end
            local moneyInfoBuyer = GetCoinTextureString(money)

            local msg
            if err == "No matching auction found" then
                msg = string.format(" Trade didn't match any guild auctions. Seller (%s) offered:%s, Buyer (%s) offered: %s",
                        seller, itemInfoSeller, buyer, moneyInfoBuyer)
            else
                msg = string.format(" Trade didn't match any guild auctions: %s. Seller (%s) offered:%s, Buyer (%s) offered: %s",
                        err, seller, itemInfoSeller, buyer, moneyInfoBuyer)
            end

            return false, msg -- No success, return the detailed message
        elseif err then
            -- Error occurred, but no specific auction candidates were even close
            return false, "Trade matching error: " .. err -- No success, return the error
        end

        return false, "No matching auction found and no specific error." -- No success, generic message if no other condition met
    end

    -- Try first direction (target as seller, player as buyer)
    -- Seller = t.targetName, Buyer = t.playerName
    -- Items = targetItemsArray (what target gives), Money = t.playerMoney (what player gives)
    local success, message1 = tryMatch(t.targetName, t.playerName, targetItemsArray, t.playerMoney)
    local message2

    -- If first attempt failed, try reverse direction (player as seller, target as buyer)
    -- Seller = t.playerName, Buyer = t.targetName
    -- Items = playerItemsArray (what player gives), Money = t.targetMoney (what target gives)
    if not success then
        _, message2 = tryMatch(t.playerName, t.targetName, playerItemsArray, t.targetMoney)
    end

    -- Print message if we got one from the failed attempts
    if not success then
        if message1 then
            print(ChatPrefix() .. message1)
        end
        if message2 then
            -- Only print message2 if message1 didn't exist or was different
            if not message1 or message1 ~= message2 then
                print(ChatPrefix() .. message2)
            end
        end
        -- If neither attempt found a match or errored informatively, add a generic failure message.
        if not message1 and not message2 then
            print(ChatPrefix() .. " Trade completed but did not match any pending guild auctions.")
        end
    else
        print(ChatPrefix() .. " Trade successfully matched with guild auction!") -- Add success confirmation
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
        local arg1, arg2 = ...
        if (arg1 == ERR_TRADE_CANCELLED) then
            -- print("[DEBUG] Trade cancelled")
            local timeSinceShow = GetTime() - self.lastTradeShowTime
            if timeSinceShow < 0.5 then
                print(ChatPrefixError() .. L[" The Go Again addon requires that both players target each other before starting a trade."])
            end
            Reset("trade cancelled")
        elseif (arg1 == ERR_TRADE_COMPLETE) then
            HandleTradeOK()
        end

    elseif event == "TRADE_SHOW" then
        CurrentTrade().targetName = GetUnitName("NPC", true)
        self.lastTradeShowTime = GetTime()

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

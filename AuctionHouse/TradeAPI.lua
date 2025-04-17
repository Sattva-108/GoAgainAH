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
        -- If the trade slot is now empty, clear our record
        items[id] = nil
        print("[DEBUG] UpdateItemInfo: Slot", id, unit, "cleared (no name).")
        return
    end

    -- Store basic info immediately, even before itemID is resolved
    -- This prevents losing the item entirely if the async call messes up later
    if not items[id] then items[id] = {} end -- Create entry if it doesn't exist
    items[id].name = name
    items[id].numItems = numItems
    -- items[id].itemID = items[id].itemID or nil -- Keep existing itemID if already resolved

    -- GetTradePlayerItemInfo annoyingly doesn't return the itemID...
    GetItemInfoAsyncWithMemoryLeak(name, function (_, itemLink)
        local currentItemEntry = items[id] -- Get the potentially existing entry

        -- Safety check: If the slot was cleared while waiting for the callback, do nothing
        if not currentItemEntry or currentItemEntry.name ~= name then
            print("[DEBUG] UpdateItemInfo Callback: Slot", id, unit, "changed/cleared while waiting. Aborting update for", name)
            return
        end

        local parsedItemID = nil
        if itemLink and type(itemLink) == "string" then
            -- Attempt to parse the itemID
            local potentialID = itemLink:match("item:(%d+):")
            if potentialID then
                parsedItemID = tonumber(potentialID)
            end
        end

        if parsedItemID then
            -- Successfully parsed a valid itemID, update the entry
            print("[DEBUG] UpdateItemInfo Callback: Slot", id, unit, "resolved ItemID", parsedItemID, "for", name)
            currentItemEntry.itemID = parsedItemID
            -- Keep name and numItems potentially updated from the outer scope if needed,
            -- though they likely haven't changed since the async call started.
            -- currentItemEntry.name = name
            -- currentItemEntry.numItems = numItems
        else
            -- Failed to parse or get a valid itemLink
            -- IMPORTANT: DO NOT set itemID to nil here if it was previously valid.
            -- Only log the failure.
            print("|cffffaa00[DEBUG] UpdateItemInfo Callback: Failed to resolve ItemID for Slot", id, unit, name, "(Link:", itemLink or "nil", ") - Keeping existing ItemID:", currentItemEntry.itemID or "nil")
            -- We intentionally DO NOT do: currentItemEntry.itemID = nil
            -- We keep whatever itemID might have been resolved previously.
        end
    end)
end

local function UpdateMoney()
    CurrentTrade().playerMoney = GetPlayerTradeMoney()
    CurrentTrade().targetMoney = GetTargetTradeMoney()
end

-- Add isDebug parameter (defaults to false if not provided)
--[[ =========================================================================
     Helper Function Dependency: ns.Serialize
     Ensure this function exists in your addon namespace (ns)
     or provide a basic fallback if needed for the debug prints.
     Example fallback:
========================================================================= ]]
if not ns.Serialize then
    ns.Serialize = function(tbl)
        if type(tbl) ~= "table" then return tostring(tbl) end
        local parts = {}
        -- Simple serialization for debug prints in chat
        for k, v in pairs(tbl) do
            local valStr
            if type(v) == "table" then valStr = "{...}" -- Keep it short for chat
            elseif type(v) == "string" then valStr = string.format("%q", v)
            else valStr = tostring(v) end
            table.insert(parts, string.format("[%s]=%s", tostring(k), valStr))
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
end

--[[ =========================================================================
     HandleTradeOK Function Definition
     Processes the completed trade, attempts to match it with addon auctions,
     and handles side effects like popups and point transfers.
     Includes an isDebug parameter for detailed logging without side effects.
========================================================================= ]]
local function HandleTradeOK(isDebug)
    isDebug = isDebug or false -- Ensure it's boolean, default to false

    if isDebug then
        print("|cffffaa00[Trade Debug] === Running HandleTradeOK (DEBUG MODE) ===|r")
    end

    -- Check if CURRENT_TRADE even exists when called
    if not CURRENT_TRADE then
        print("|cffff5555[Trade Debug] HandleTradeOK called but CURRENT_TRADE is nil! (Debug:", tostring(isDebug), ")|r")
        -- In normal mode, Reset might still be appropriate. In debug, just return.
        if not isDebug then Reset("HandleTradeOK - No Current Trade") end
        return
    end

    local t = CurrentTrade()
    print("|cffcccccc[Trade Debug] HandleTradeOK: Initial Trade Data:|r")
    -- Basic printout using GetCoinTextureString for money
    print(string.format("  Player: %s, Target: %s", t.playerName or "N/A", t.targetName or "N/A"))
    print(string.format("  Player $: %s, Target $: %s", GetCoinTextureString(t.playerMoney or 0), GetCoinTextureString(t.targetMoney or 0)))
    print("  Player Items (Raw):", ns.Serialize(t.playerItems)) -- Use Serialize helper
    print("  Target Items (Raw):", ns.Serialize(t.targetItems)) -- Use Serialize helper


    -- Get the items that were traded, filtering out items where itemID lookup might have failed
    local playerItems = {}
    local targetItems = {}

    print("|cffcccccc[Trade Debug] HandleTradeOK: Processing Player Items:|r")
    if t.playerItems then
        for id, item in pairs(t.playerItems) do
            if item and type(item) == "table" then -- Basic check if item exists and is a table
                local itemIDStr = item.itemID and tostring(item.itemID) or "|cffff7777pending/missing ID|r"
                local itemName = item.name or "|cffff7777Unknown Name|r"
                local numItems = item.numItems or 0
                print(string.format("  - Slot %d: %s x%d (ID: %s)", id, itemName, numItems, itemIDStr))
                if item.itemID then -- Only add if itemID is resolved and valid
                    table.insert(playerItems, {
                        itemID = item.itemID,
                        count = numItems
                    })
                else
                    print("|cffffaa00    -> Warning: ItemID missing/invalid for slot", id, ", will not be included in final list for matching.|r")
                end
            elseif item then
                print(string.format("  - Slot %d: |cffff5555Invalid item data (not a table?)|r", id))
                -- else: slot might be empty, which is normal
            end
        end
    else
        print("  (No player items table in CURRENT_TRADE)")
    end


    print("|cffcccccc[Trade Debug] HandleTradeOK: Processing Target Items:|r")
    if t.targetItems then
        for id, item in pairs(t.targetItems) do
            if item and type(item) == "table" then
                local itemIDStr = item.itemID and tostring(item.itemID) or "|cffff7777pending/missing ID|r"
                local itemName = item.name or "|cffff7777Unknown Name|r"
                local numItems = item.numItems or 0
                print(string.format("  - Slot %d: %s x%d (ID: %s)", id, itemName, numItems, itemIDStr))
                if item.itemID then
                    table.insert(targetItems, {
                        itemID = item.itemID,
                        count = numItems
                    })
                else
                    print("|cffffaa00    -> Warning: ItemID missing/invalid for slot", id, ", will not be included in final list for matching.|r")
                end
            elseif item then
                print(string.format("  - Slot %d: |cffff5555Invalid item data (not a table?)|r", id))
                -- else: slot might be empty
            end
        end
    else
        print("  (No target items table in CURRENT_TRADE)")
    end

    -- Add gold as fake item logic if no actual items were successfully processed
    if #playerItems == 0 and #targetItems == 0 then
        print("|cffcccccc[Trade Debug] HandleTradeOK: No valid items found in formatted lists, checking gold.|r")
        if t.playerMoney and t.playerMoney > 0 then
            print("  - Adding Player Gold as Item:", t.playerMoney)
            table.insert(playerItems, {
                itemID = ns.ITEM_ID_GOLD, -- Ensure ns.ITEM_ID_GOLD is defined
                count = t.playerMoney
            })
        end
        if t.targetMoney and t.targetMoney > 0 then
            print("  - Adding Target Gold as Item:", t.targetMoney)
            table.insert(targetItems, {
                itemID = ns.ITEM_ID_GOLD, -- Ensure ns.ITEM_ID_GOLD is defined
                count = t.targetMoney
            })
        end
    end

    print("|cffcccccc[Trade Debug] HandleTradeOK: Final Formatted Lists for Matching:|r")
    print("  - Final Player Items:", ns.Serialize(playerItems))
    print("  - Final Target Items:", ns.Serialize(targetItems))
    print(string.format("  - Player Money for Matching: %d", t.playerMoney or 0))
    print(string.format("  - Target Money for Matching: %d", t.targetMoney or 0))

    -- Inner function to attempt matching and handle side effects based on isDebug
    -- Returns: success (boolean), message (string or nil)
    local function tryMatch(seller, buyer, items, money)
        print(string.format("|cffaaaaff[Trade Debug] tryMatch (Seller=%s, Buyer=%s, Money=%d). Debug=%s|r",
                seller or "nil", buyer or "nil", money or 0, tostring(isDebug)))
        print("  - Items to Match:", ns.Serialize(items))

        --[[ =============================================================
             DEPENDENCY: ns.AuctionHouseAPI:TryCompleteItemTransfer
             Make sure this function exists and accepts the isDebug flag.
        ============================================================= ]]
        local success, hadCandidates, err, trade = ns.AuctionHouseAPI:TryCompleteItemTransfer(
                seller,
                buyer,
                items,
                money,
                ns.DELIVERY_TYPE_TRADE, -- Ensure ns.DELIVERY_TYPE_TRADE is defined
                isDebug -- Pass the flag here
        )

        print("|cffaaaaff[Trade Debug] tryMatch Result: Success=", tostring(success), "HadCandidates=", tostring(hadCandidates), "Err=", err or "nil", "TradeID=", (trade and trade.id or "nil"))

        if success and trade then
            print("|cff55ff55[Trade Debug]   -> Match SUCCESSFUL (Trade ID:", trade.id, ")|r")
            if isDebug then
                print("|cffffaa00    --> SKIPPING StaticPopup_Show in debug mode.|r")
                print("|cffffaa00    --> SKIPPING PendingTxAPI calls in debug mode.|r")
            else
                -- Only show popup and handle points if not in debug mode
                StaticPopup_Show("OF_LEAVE_REVIEW", nil, nil, { tradeID = trade.id }) -- Ensure OF_LEAVE_REVIEW popup exists

                -- Example: Handle points transfer (ensure required ns constants/APIs exist)
                if trade.auction and trade.auction.priceType == ns.PRICE_TYPE_GUILD_POINTS then
                    print("|cff00ccff[Trade Info] Handling Guild Points transfer for auction:", trade.auction.id) -- Normal log
                    --[[ =============================================================
                         DEPENDENCY: ns.PendingTxAPI
                         Make sure AddPendingTransaction and HandlePendingTransactionChange exist.
                    ============================================================= ]]
                    local tx, txErr = ns.PendingTxAPI:AddPendingTransaction({
                        type = ns.PRICE_TYPE_GUILD_POINTS,
                        amount = trade.auction.points or 0,
                        from = trade.auction.buyer,
                        to = trade.auction.owner,
                        id = trade.auction.id,
                    })
                    if tx then
                        print("|cff00ccff[Trade Info] Added Pending Points Tx. Applying locally.|r") -- Normal log
                        ns.PendingTxAPI:HandlePendingTransactionChange(tx)
                    else
                        -- Use ChatPrefixError and L for user-facing errors
                        print(ChatPrefixError() .. (L[" Failed to transfer points:"] or " Failed to transfer points:") .. " " .. (txErr or "Unknown error"))
                    end
                end
            end
            -- Return success, no error message needed
            return true, nil
        elseif err then -- If there was an error message returned (even if candidates existed)
            print("|cffffaaaa[Trade Debug]   -> Match FAILED. Error:", err, "|r")
            local itemInfoStr = "" -- Simplified item info for error message
            if items and items[1] then itemInfoStr = itemInfoStr .. " (" .. (seller == t.playerName and "P" or "T") .. ":" .. items[1].itemID .. "x" .. items[1].count .. ")" end

            local fullErrMsg
            -- Use localization (L) if available, otherwise use defaults
            local noMatchStr = L["No matching auction found"] or "No matching auction found"
            if err == noMatchStr then
                fullErrMsg = L[" Trade didn't match any guild auctions"] or " Trade didn't match any guild auctions"
            else
                fullErrMsg = (L[" Trade failed: "] or " Trade failed: ") .. err
            end
            fullErrMsg = fullErrMsg .. itemInfoStr
            return false, fullErrMsg -- Failure, return the constructed error message
        else -- No success, but no specific error message (likely hadCandidates was false)
            print("|cffffaaaa[Trade Debug]   -> Match FAILED (No specific error returned, likely no candidates).|r")
            local genericMsg = L[" Trade didn't match any guild auctions"] or " Trade didn't match any guild auctions"
            return false, genericMsg -- Return generic failure message
        end
    end

    -- Try first direction (target as seller)
    print("|cffcccccc[Trade Debug] HandleTradeOK: Attempting match 1 (Target selling to Player)|r")
    local success1, message1 = tryMatch(t.targetName, t.playerName, targetItems, t.playerMoney or 0)
    local success2, message2

    -- If first attempt failed, try reverse direction
    if not success1 then
        print("|cffcccccc[Trade Debug] HandleTradeOK: Attempting match 2 (Player selling to Target)|r")
        success2, message2 = tryMatch(t.playerName, t.targetName, playerItems, t.targetMoney or 0)
    end

    -- Decide which message to show (if any), only if not in debug mode and both attempts failed
    local finalMessage = nil
    if not success1 and not success2 then -- Both attempts failed
        -- Prioritize the message from the first attempt if it exists, otherwise use the second, or a default.
        finalMessage = message1 or message2 or (L["Trade failed for unknown reason."] or "Trade failed for unknown reason.")
        -- If either attempt succeeded, the success handling (popups etc) was done inside tryMatch.
        -- No additional message needed here for success cases.
    end

    if isDebug then
        print("|cffffaa00  --> SKIPPING final print message in debug mode (Simulated Final Message:", finalMessage or "nil", ")|r")
    elseif finalMessage then
        -- Use ChatPrefixError for failure messages
        print(ChatPrefixError() .. finalMessage)
    end

    -- Reset the trade state (ONLY if not in debug mode)
    if isDebug then
        print("|cffffaa00[Trade Debug] === SKIPPING Reset() in debug mode ===|r")
    else
        print("|cffcccccc[Trade Info] HandleTradeOK: Calling Reset() (Normal Mode)|r") -- Use Info level for normal operation
        --[[ =============================================================
             DEPENDENCY: Reset()
             Ensure this function exists to clear the CURRENT_TRADE state.
        ============================================================= ]]
        Reset("HandleTradeOK") -- Pass source for logging in Reset if it supports it
    end

    print("|cffcccccc[Trade Debug] HandleTradeOK: Exiting (Debug:", tostring(isDebug), ")|r")

end

-- Add near CURRENT_TRADE definition
local isTradeFinalizing = false

-- Update Reset function
local function Reset(source)
    ns.DebugLog("[DEBUG] Reset Trade " .. (source or ""))
    CURRENT_TRADE = nil
    isTradeFinalizing = false -- Reset the flag
end


-- Single event handler function
--[[ =========================================================================
     Prerequisites:
     - Assumes 'local addonName, ns = ...' and 'local TradeAPI = {}' etc. are defined above.
     - Assumes 'CURRENT_TRADE', 'CurrentTrade()', 'CreateNewTrade()' are defined.
     - Assumes 'Reset(source)' function exists and clears CURRENT_TRADE.
     - Assumes 'UpdateItemInfo(id, unit, items)' function exists.
     - Assumes 'UpdateMoney()' function exists.
     - Assumes 'HandleTradeOK(isDebug)' function exists.
     - Assumes 'ns.DebugLog', 'print', 'ChatPrefix', 'ChatPrefixError', 'L' (localization) exist.
     - Assumes WoW API functions like GetTime, GetUnitName, etc. are available.
========================================================================= ]]

-- Flag to lock the trade state once acceptance starts
local isTradeFinalizing = false

-- Ensure the Reset function clears the flag
local originalReset = Reset -- Keep a reference if Reset is defined elsewhere
Reset = function(source)
    ns.DebugLog("[DEBUG] Resetting Trade (" .. (source or "Unknown") .. ") and clearing finalizing flag.")
    if originalReset then originalReset(source) end -- Call the original Reset logic
    CURRENT_TRADE = nil -- Explicitly ensure CURRENT_TRADE is nil
    isTradeFinalizing = false -- <<< Reset the flag here >>>
end

-- Single event handler function for TradeAPI
function TradeAPI:OnEvent(event, ...)
    -- Early exit if event is irrelevant or state is locked inappropriately
    -- (Add more checks here if needed based on addon structure)

    if event == "MAIL_SHOW" then
        -- Potentially reset trade state if opening mail invalidates a trade? (Optional)
        -- Reset("MAIL_SHOW")
        ns.DebugLog("[DEBUG] MAIL_SHOW")

    elseif event == "MAIL_CLOSED" then
        ns.DebugLog("[DEBUG] MAIL_CLOSED")

    elseif event == "UI_ERROR_MESSAGE" then
        local _, arg2 = ...
        if (arg2 == ERR_TRADE_BAG_FULL or
                arg2 == ERR_TRADE_TARGET_BAG_FULL or
                arg2 == ERR_TRADE_MAX_COUNT_EXCEEDED or
                arg2 == ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED or
                arg2 == ERR_TRADE_TARGET_DEAD or
                arg2 == ERR_TRADE_TOO_FAR) then
            ns.DebugLog("[DEBUG] Trade failed due to error:", arg2)
            Reset("trade failed error: " .. arg2)  -- trade failed, reset state and flag
        end

    elseif event == "UI_INFO_MESSAGE" then
        local arg1, arg2 = ...
        if (arg1 == ERR_TRADE_CANCELLED) then
            ns.DebugLog("[DEBUG] Trade cancelled.")
            -- Check for potential targeting issue hint
            local timeSinceShow = GetTime() - (self.lastTradeShowTime or 0)
            if timeSinceShow < 0.5 then
                print(ChatPrefixError() .. L[" The Go Again addon requires that both players target each other before starting a trade."])
            end
            Reset("trade cancelled") -- Trade cancelled, reset state and flag

        elseif (arg1 == ERR_TRADE_COMPLETE) then
            -- Trade completed successfully
            print("|cff00ff00[Trade Info] TRADE_COMPLETE received. Running HandleTradeOK (Normal Mode).|r")
            -- The isTradeFinalizing flag should be true here from TRADE_ACCEPT_UPDATE.
            -- HandleTradeOK(false) will use the frozen state and then call Reset() internally.
            HandleTradeOK(false) -- Execute the normal completion logic
            -- Note: HandleTradeOK(false) MUST call Reset() internally to clear the flag.
        end

    elseif event == "TRADE_SHOW" then
        ns.DebugLog("[DEBUG] TRADE_SHOW received. Resetting trade state.")
        Reset("TRADE_SHOW") -- Start of a new trade, reset everything including flag
        CurrentTrade().targetName = GetUnitName("NPC", true) -- Get target name for the new trade
        self.lastTradeShowTime = GetTime() -- Track show time for cancel message logic

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        if isTradeFinalizing then
            ns.DebugLog("[DEBUG] Player ITEM_CHANGED ignored (finalizing).")
            return -- <<<<< GUARD: Do not update state after acceptance starts
        end
        local arg1 = ...
        ns.DebugLog("[DEBUG] Player ITEM_CHANGED", arg1, "- Updating...")
        UpdateItemInfo(arg1, "Player", CurrentTrade().playerItems)

    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        if isTradeFinalizing then
            ns.DebugLog("[DEBUG] Target ITEM_CHANGED ignored (finalizing).")
            return -- <<<<< GUARD: Do not update state after acceptance starts
        end
        local arg1 = ...
        ns.DebugLog("[DEBUG] Target ITEM_CHANGED", arg1, "- Updating...")
        UpdateItemInfo(arg1, "Target", CurrentTrade().targetItems)

    elseif event == "TRADE_MONEY_CHANGED" then
        if isTradeFinalizing then
            ns.DebugLog("[DEBUG] TRADE_MONEY_CHANGED ignored (finalizing).")
            return -- <<<<< GUARD: Do not update state after acceptance starts
        end
        ns.DebugLog("[DEBUG] TRADE_MONEY_CHANGED - Updating...")
        UpdateMoney()

    elseif event == "TRADE_ACCEPT_UPDATE" then
        print("|cffcccc00[Trade Debug] TRADE_ACCEPT_UPDATE received.|r")

        -- Prevent running updates/debug call multiple times if both players accept very quickly
        -- or if the event fires multiple times for one acceptance.
        if isTradeFinalizing then
            print("|cffcccc00[Trade Debug] Already finalizing, skipping redundant update/debug call.|r")
            return
        end

        -- Set the flag *before* the final update to lock the state
        isTradeFinalizing = true
        print("|cffcccc00[Trade Debug] Setting isTradeFinalizing = true. State frozen.|r")

        -- Perform one last data update *right now* to capture the state at acceptance
        print("|cffcccc00[Trade Debug] Performing final data update...|r")
        local trade = CurrentTrade() -- Get current trade object
        if not trade then
            print("|cffff0000[Trade Debug] Error: CURRENT_TRADE is nil during TRADE_ACCEPT_UPDATE final update!|r")
            -- Attempt to reset to handle error state
            Reset("Error - nil trade on accept update")
            return
        end
        -- Update using the existing trade object's tables
        for i = 1, 7 do -- Use appropriate max trade slot number (e.g., 7 for Retail, 6 for Classic?)
            UpdateItemInfo(i, "Player", trade.playerItems)
            UpdateItemInfo(i, "Target", trade.targetItems)
        end
        UpdateMoney() -- Ensure money is also captured

        -- Optional: Short delay to allow async ItemInfo lookups triggered above a tiny bit more time.
        -- Might help resolve itemIDs, but isn't guaranteed. The robust UpdateItemInfo is more important.
        -- C_Timer.After(0.1, function() -- Very short delay

        -- Run the debug check with the *now frozen* state
        print("|cffcccc00[Trade Debug] Final data updated. Calling HandleTradeOK in DEBUG mode...|r")
        -- Use pcall for safety, especially during debugging phases
        local success, err = pcall(HandleTradeOK, true) -- Pass true for isDebug
        if not success then
            print("|cffff0000[Trade Debug] Error during HandleTradeOK (DEBUG) execution:|r", err)
        end
        print("|cffcccc00[Trade Debug] Finished HandleTradeOK (DEBUG) execution. State is now locked.|r")

        -- end) -- End of optional C_Timer.After

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

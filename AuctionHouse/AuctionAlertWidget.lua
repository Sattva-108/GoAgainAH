local addonName, ns = ...

local AuctionAlertWidget = {}
ns.AuctionAlertWidget = AuctionAlertWidget

local API = ns.AuctionHouseAPI

function CreateAlertFrame()
    alertFrame = CreateFrame("Frame", "AuctionAlertWidgetFrame", UIParent)
    alertFrame:SetSize(750, 40)
    alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 275)
	alertFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	alertFrame:SetFrameLevel(100) -- Lots of room to draw under it
    alertFrame:EnableMouse(false)
    alertFrame:SetMovable(false)
    alertFrame:Hide()

    local bg = alertFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetVertexColor(0, 0, 0, 0.4)

    local text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", alertFrame, "CENTER")
    text:SetWidth(740)
    text:SetJustifyH("CENTER")
    text:SetParent(alertFrame)
    -- white
    text:SetTextColor(1, 1, 1, 1)
    alertFrame.text = text

    return alertFrame
end

-- Shows the frame and sets the text
function AuctionAlertWidget:ShowAlert(message)
    if not alertFrame then
        self.alertFrame = CreateAlertFrame()
    end

    -- Initialize or increment the counter
    alertFrame.hideCounter = (alertFrame.hideCounter or 0) + 1

    alertFrame.text:SetText(message)
    alertFrame:Show()

    -- Hide automatically after a few seconds
    C_Timer:After(5, function()
        if alertFrame then
            -- Decrement counter and only hide if it reaches 0
            alertFrame.hideCounter = alertFrame.hideCounter - 1
            if alertFrame.hideCounter <= 0 then
                alertFrame:Hide()
            end
        end
    end)
end

-- Add this near the top of the file or in your core addon file where 'ns' is defined
ns.lastCompleteMessageTime = ns.lastCompleteMessageTime or {}

-- Modified CreateAlertMessage function
local function CreateAlertMessage(auction, buyer, buyerName, owner, ownerName, itemLink, payload)
    local me = UnitName("player")

    -- Use a localized format for quantity; if more than 1 use a multiplier string:
    local quantityStr = auction.quantity > 1 and string.format(L["x%d"], auction.quantity) or ""
    if ns.IsFakeItem(auction.itemID) then
        quantityStr = ""
    end

    if not itemLink then
        itemLink = L["Unknown Item"]
    end

    -- Helper function to get delivery instruction
    local function getDeliveryInstruction(duel, deathRoll, deliveryType)
        if duel then
            return L["Duel and trade them"]
        elseif deathRoll then
            return L["Deathroll and trade them"]
        elseif deliveryType == ns.DELIVERY_TYPE_MAIL then
            return L["Open the mailbox to accept"]
        elseif deliveryType == ns.DELIVERY_TYPE_TRADE then
            return L["Trade them to accept"]
        else
            return L["Open the mailbox or trade them to accept"]
        end
    end
    -- Convert names to hyperlinks for chat messages
    local buyerLink = CreatePlayerLink(buyer)
    local ownerLink = CreatePlayerLink(owner)
    local otherUserLink = auction.owner == me and buyerLink or ownerLink

    local msg, msgChat, extraMsg = nil, nil, nil
    if payload.source == "status_update" then
        msg = string.format(L["%s sent you a mail for %s%s"],
            ownerName, itemLink, quantityStr)
        msgChat = string.format(L["%s %s |cffffcc00sent you a mail for %s%s. It will arrive in 1 hour|r"],
            ChatPrefix(), ownerLink, itemLink, quantityStr)

    elseif payload.source == "buy_loan" then
        local deliveryInstruction = getDeliveryInstruction(auction.duel, auction.deathRoll, auction.deliveryType)

        if auction.raidAmount > 0 then
            msg = string.format(L["%s wants to raid you for your %s%s"],
                buyerName, itemLink, quantityStr)
            msgChat = string.format(L["%s %s|cffffcc00 wants to raid you for your %s%s. %s|r"],
                ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
        elseif auction.duel then
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and duel for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and duel for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to duel for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to duel for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        elseif auction.deathRoll then
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and deathroll for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and deathroll for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to deathroll for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to deathroll for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        else
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and loan-buy your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and loan-buy your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to loan-buy your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to loan-buy your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        end

    elseif payload.source == "buy" and not auction.wish then
        local deliveryInstruction = getDeliveryInstruction(auction.duel, auction.deathRoll, auction.deliveryType)

        if auction.raidAmount > 0 then
            msg = string.format(L["%s wants to raid you for your %s%s"],
                buyerName, itemLink, quantityStr)
            msgChat = string.format(L["%s %s|cffffcc00 wants to raid you for your %s%s. %s|r"],
                ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
        elseif auction.duel then
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and duel for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and duel for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to duel for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to duel for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        elseif auction.deathRoll then
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and deathroll for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and deathroll for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to deathroll for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to deathroll for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        elseif ns.IsFakeItem(auction.itemID) then
            if auction.roleplay then
                msg = string.format(L["%s wants to RP for your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP for your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        else
            if auction.roleplay then
                msg = string.format(L["%s wants to RP and buy your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to RP and buy your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            else
                msg = string.format(L["%s wants to buy your %s%s"],
                    buyerName, itemLink, quantityStr)
                msgChat = string.format(L["%s %s|cffffcc00 wants to buy your %s%s. %s|r"],
                    ChatPrefix(), buyerLink, itemLink, quantityStr, deliveryInstruction)
            end
        end

    elseif payload.source == "buy" and auction.wish then
        if auction.roleplay then
            msg = string.format(L["%s is RPing and fulfilling your wishlist item %s%s"],
                ownerName, itemLink, quantityStr)
            msgChat = string.format(L["%s %s |cffffcc00is RPing and fulfilling your wishlist item %s%s|r"],
                ChatPrefix(), ownerLink, itemLink, quantityStr)
        else
            msg = string.format(L["%s is fulfilling your wishlist item %s%s"],
                ownerName, itemLink, quantityStr)
            msgChat = string.format(L["%s %s |cffffcc00is fulfilling your wishlist item %s%s|r"],
                ChatPrefix(), ownerLink, itemLink, quantityStr)
        end

    elseif payload.source == "complete" then
        -- ***** START DEBOUNCE LOGIC *****
        local now = GetTime()
        local auctionId = auction.id
        local threshold = 3 -- Only suppress duplicates within 3 seconds (adjustable)

        -- Check if we recently generated a message for this auction completion
        if ns.lastCompleteMessageTime[auctionId] and (now - ns.lastCompleteMessageTime[auctionId] < threshold) then
            -- Optional: Log suppression for debugging if needed
            -- ns.DebugLog("Suppressing duplicate 'complete' message for auction:", auctionId)
            return nil, nil, nil -- Return nils to prevent message generation
        end

        -- Record the time we are generating this message
        ns.lastCompleteMessageTime[auctionId] = now
        -- ***** END DEBOUNCE LOGIC *****

        -- Don't show alert banner on complete (original logic)
        msg = nil
        -- Generate the chat messages (original logic)
        msgChat = string.format(L["%s |cffffcc00Transaction successful|r, %s%s with %s"],
                ChatPrefix(), itemLink, quantityStr, otherUserLink)
        extraMsg = string.format(L["%s Write your review in the OnlyFangs AH Addon"],
                ChatPrefix())

    end -- End of payload.source checks

    return msg, msgChat, extraMsg
end

local function OnAuctionAddOrUpdate(payload)
    -- Ensure payload and auction data exist
    if not payload or not payload.auction then
        -- Optional: Log error if needed
        -- ns.DebugLog("OnAuctionAddOrUpdate called with invalid payload")
        return
    end
    local auction = payload.auction

    -- Only process specific event sources that should trigger alerts
    if payload.source ~= "buy" and
            payload.source ~= "buy_loan" and
            payload.source ~= "status_update" and
            payload.source ~= "complete" then
        return
    end

    local me = UnitName("player") -- Get current player name

    -- Filter alerts based on player involvement and event source
    local shouldShowAlert = false
    if payload.source == "buy" and auction.wish then
        -- Wish fulfillment alert: Only show to the buyer (recipient)
        if auction.buyer == me then
            shouldShowAlert = true
        end
    elseif payload.source == "status_update" then
        -- Mail sent alert: Only show to the buyer (recipient)
        -- and only for specific statuses indicating mail was sent
        if auction.buyer == me and
                (auction.status == ns.AUCTION_STATUS_SENT_LOAN or auction.status == ns.AUCTION_STATUS_SENT_COD) then
            shouldShowAlert = true
        end
    elseif payload.source == "complete" then
        -- Completion alert: Show to both buyer and owner
        if auction.buyer == me or auction.owner == me then
            shouldShowAlert = true
        end
    else -- Covers "buy" (non-wish) and "buy_loan"
        -- Purchase/Loan request alert: Only show to the owner
        -- Ensure there *is* a buyer and it's not the owner themselves
        if auction.owner == me and auction.buyer and auction.buyer ~= me then
            shouldShowAlert = true
        end
    end

    -- If the filtering logic determines no alert should be shown for this player, exit early
    if not shouldShowAlert then
        return
    end

    -- Asynchronously get item info needed for the alert message
    -- Pass auction.quantity to potentially handle item counts in GetItemInfoAsync if needed
    ns.GetItemInfoAsync(auction.itemID, function(itemID, itemLink, ...) -- Assuming callback provides itemID and itemLink first
        -- Re-check itemLink validity inside callback
        if not itemLink then
            itemLink = L["Unknown Item"] -- Fallback inside callback
        end

        -- Get display names, potentially truncated
        local buyerName = ns.GetDisplayName(auction.buyer, nil, 40) -- Max 40 chars
        local ownerName = ns.GetDisplayName(auction.owner, nil, 40) -- Max 40 chars

        -- Generate the alert message components using the helper function
        -- This function might return nils if the message is debounced/suppressed
        local msg, msgChat, extraMsg = CreateAlertMessage(auction, auction.buyer, buyerName, auction.owner, ownerName, itemLink, payload)

        -- *** Process generated messages only if they exist ***
        if msgChat or extraMsg or msg then -- Check if at least one message component was generated

            -- Play sound effect for the alert
            PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)

            -- Add primary chat message if it exists and is a string
            if msgChat and type(msgChat) == "string" then
                DEFAULT_CHAT_FRAME:AddMessage(msgChat)
            end

            -- Add secondary chat message if it exists and is a string
            if extraMsg and type(extraMsg) == "string" then
                DEFAULT_CHAT_FRAME:AddMessage(extraMsg)
            end

            -- Show the alert widget message if it exists and is a string
            if msg and type(msg) == "string" then
                -- Ensure the widget and its method exist before calling
                if AuctionAlertWidget and AuctionAlertWidget.ShowAlert then
                    AuctionAlertWidget:ShowAlert(msg)
                else
                    -- Optional: Log if widget is missing when expected
                    -- ns.DebugLog("AuctionAlertWidget or ShowAlert method not found.")
                end
            end

            -- else: No messages were generated (likely debounced), do nothing further.

        end -- End of check if messages were generated

    end, auction.quantity) -- End of ns.GetItemInfoAsync call
end -- End of OnAuctionAddOrUpdate function

function AuctionAlertWidget:OnInitialize()
    API:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, OnAuctionAddOrUpdate)
    -- state sync updates also trigger widget alerts
    API:RegisterEvent(ns.T_AUCTION_SYNCED, OnAuctionAddOrUpdate)
end

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
        -- Don't show alert on complete (in most cases, you just did a UI action, so an extra banner is unexpected)
        msg = nil
        msgChat = string.format(L["%s |cffffcc00Transaction successful|r, %s%s with %s"],
            ChatPrefix(), itemLink, quantityStr, otherUserLink)
        extraMsg = string.format(L["%s Write your review in the OnlyFangs AH Addon"],
            ChatPrefix())
    end

    return msg, msgChat, extraMsg
end

local lastCompleteShown = {}
local function OnAuctionAddOrUpdate(payload)
    local auction = payload.auction
    if not auction then
        return
    end

    -- Only show alerts for specific events
    if payload.source ~= "buy" and payload.source ~= "buy_loan" and payload.source ~= "status_update" and payload.source ~= "complete" then
        return
    end

    local me = UnitName("player")

    -- Different conditions based on source
    if payload.source == "buy" and auction.wish then
        -- only trigger alert for the buyer of the auction
        if auction.buyer ~= me then
            return
        end
    elseif payload.source == "status_update" then
        if auction.buyer ~= me then
            return
        end
        if auction.status ~= ns.AUCTION_STATUS_SENT_LOAN and auction.status ~= ns.AUCTION_STATUS_SENT_COD then
            return
        end
    elseif payload.source == "complete" then
        local id = auction.id or (auction.itemID .. ":" .. (auction.buyer or "") .. ":" .. (auction.owner or ""))
        if lastCompleteShown[id] then
            return
        end
        lastCompleteShown[id] = true
    else
        if auction.owner ~= me then
            return
        end
        if not auction.buyer or auction.buyer == me then
            return
        end
    end

    local lookup = auction.link or auction.itemID
    ns.GetItemInfoAsync(lookup, function(...)
        local _, itemLink = ...

        -- Limit names to 40 characters
        local buyerName = ns.GetDisplayName(auction.buyer, nil, 40)
        local ownerName = ns.GetDisplayName(auction.owner, nil, 40)

        local msg, msgChat, extraMsg = CreateAlertMessage(auction, auction.buyer, buyerName, auction.owner, ownerName, itemLink, payload)

        PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
        DEFAULT_CHAT_FRAME:AddMessage(msgChat)
        if extraMsg then
            DEFAULT_CHAT_FRAME:AddMessage(extraMsg)
        end

        if msg then
            AuctionAlertWidget:ShowAlert(msg)
        end
    end, auction.quantity)
end

function AuctionAlertWidget:OnInitialize()
    API:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, OnAuctionAddOrUpdate)
    -- state sync updates also trigger widget alerts
    API:RegisterEvent(ns.T_AUCTION_SYNCED, OnAuctionAddOrUpdate)
end

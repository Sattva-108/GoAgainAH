local addonName, ns = ...
local AuctionHouse = ns.AuctionHouse

local MailboxUI = AuctionHouse:NewModule("MailboxUI", "AceEvent-3.0")
ns.MailboxUI = MailboxUI

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

StaticPopupDialogs["GAH_MAIL_CANCEL_AUCTION"] = {
    text = "Are you sure you want to cancel this auction?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if data and data.auctionId then
            ns.AuctionHouseAPI:CancelAuction(data.auctionId)
            ClearMailFields()
        end
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

ns.GetExpectedCopperForMail = function(auction)
    local expectedCopper = (auction.price or 0) + (auction.tip or 0)

    if auction.itemID == ns.ITEM_ID_GOLD then
        expectedCopper = auction.quantity
    elseif ns.IsFakeItem(auction.itemID) then
        expectedCopper = 0
    elseif auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
        expectedCopper = 0
    end

    return expectedCopper
end

function MailboxUI:ValidateMailForAuction(auctionId, overrideRecipient)
    local auction = ns.AuctionHouseDB.auctions[auctionId]
    if not auction then
        return false, "Auction not found"
    end

    -- Check mail recipient using stored value instead of UI element
    local recipient = overrideRecipient or self.currentRecipient
    if recipient ~= auction.buyer then
        return false, string.format("Invalid recipient. Required: %s, Current: %s",
            auction.buyer, recipient or "")
    end

    -- Check money amount
    local expectedCopper = ns.GetExpectedCopperForMail(auction)

    local moneyOk = self.currentMailCopper >= expectedCopper

    -- Check items
    local totalQuantity = 0
    if auction.itemID == ns.ITEM_ID_GOLD then
        totalQuantity = GetMoney()
    else
        for _, item in pairs(self.currentMailItems) do
            if item.id == auction.itemID then
                totalQuantity = totalQuantity + (item.count or 1)
            end
        end
    end
    local itemsOk = totalQuantity >= auction.quantity

    if not moneyOk then
        return false, string.format("Invalid money amount. Required: %d copper, Current: %d copper",
            expectedCopper, self.currentMailCopper)
    end

    if not itemsOk then
        return false, string.format("Insufficient items. Required: %d, Current: %d",
            auction.quantity, totalQuantity)
    end

    return true
end

function MailboxUI:CreateMailboxUI()
    -- Only build the base UI once
    if self.mailboxUI then return end

    self.currentPage = 1
    self.auctionsPerPage = 3
    self.orderSlots = {}

    -- Create a container frame (AceGUI Frame)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("OnlyFangs AH")
    frame:SetStatusText("")
    frame:SetLayout("Flow")
    frame:EnableResize(false)

    -- ensure popups (eg confirm unlist all) render above the frame
    frame.frame:SetFrameStrata("LOW")
    frame.frame:SetFrameLevel(100)
    frame.content:SetPoint("TOPLEFT", 5, -18)

    -- Hide the close button and frame's status background
    for _, child in pairs({frame.frame:GetChildren()}) do
        if child:IsObjectType("Button") and child:GetText() == CLOSE then
            child:Hide()
        elseif child:IsObjectType("Button") and child:GetBackdrop() then
            child:Hide()
        end
    end

    -- Add custom close button
    local closeButton = CreateFrame("Button", nil, frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 3, 1)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Position it to the right of the MailFrame
    frame.frame:ClearAllPoints()
    frame.frame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 3, 3)
    frame.frame:SetClampedToScreen(true)

    frame.frame:SetHeight(MailFrame:GetHeight() + 6)
    frame.frame:SetWidth(425)

    -- undo defaults from AceGUI Frame
    frame.content:SetWidth(425)
	frame.content:SetPoint("TOPLEFT", 4, -24)
	frame.content:SetPoint("BOTTOMRIGHT", -4, 4)

    frame.frame:SetBackdrop({
        bgFile = "Interface/AddOns/" .. addonName .. "/Media/Square_FullWhite.tga",
        tile = true,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame.frame:SetBackdropColor(0.125, 0.118, 0.106, 0.98)
    frame.frame:SetBackdropBorderColor(0.298, 0.294, 0.298, 1)


    -- "No Orders" message
    self.noOrdersLabel = AceGUI:Create("Label")
    self.noOrdersLabel:SetText("No Pending Orders")
    self.noOrdersLabel:SetFont(GameFontNormalLarge:GetFont())
    self.noOrdersLabel:SetFullWidth(true)
    self.noOrdersLabel:SetJustifyH("CENTER")
    frame:AddChild(self.noOrdersLabel)
    self.noOrdersLabel.label:Hide()

    ----------------------------------------------------------------------------
    -- Create 3 static "slots" for items (one per row).
    ----------------------------------------------------------------------------
    local function CreateOrderSlot(i)
        local orderGroup = AceGUI:Create("SimpleGroup")
        orderGroup:SetWidth(425)
        orderGroup:SetLayout("List")

        -- Remove the default padding
        orderGroup.content:SetPoint("TOPLEFT", 1, 0)
        orderGroup.content:SetPoint("BOTTOMRIGHT", 0, 0)

        local rowbg = orderGroup.frame:CreateTexture(nil, "BACKGROUND")
        rowbg:SetParent(orderGroup.content)
        rowbg:SetColorTexture(1, 1, 1, 0.05)
        rowbg:SetPoint("TOPLEFT", 0, 0)
        rowbg:SetPoint("BOTTOMRIGHT", 0, 0)
        orderGroup.rowBackground = rowbg  -- Store reference to background

        -- Add show/hide methods
        function orderGroup:ShowSlot()
            self.content:Show()
        end

        function orderGroup:HideSlot()
            self.content:Hide()
        end

        -- Header: Owner info
        local header = AceGUI:Create("SimpleGroup")
        header:SetFullWidth(true)
        header:SetLayout("Flow")
        header:SetHeight(200)
        header.content:SetPoint("TOPLEFT", 6, 0)
        header.content:SetPoint("BOTTOMRIGHT", 10, 0)

        -- Owner name and rating container
        local ownerContainer = AceGUI:Create("SimpleGroup")
        ownerContainer:SetLayout("Flow")
        ownerContainer:SetFullWidth(true)

        local username = AceGUI:Create("Label")
        username:SetText("Loading...")
        username:SetFontObject(GameFontNormalSmall)
        username:SetWidth(180)
        ownerContainer:AddChild(username)

        local starRating = ns.CreateStarRatingWidget({
            starSize = 9,
            panelHeight = 9,
            marginBetweenStarsX = 2,
            textWidth = 22,
            leftMargin = 1,
        })
        ownerContainer:AddChild(starRating)

        local space = AceGUI:Create("Label")
        space:SetWidth(16)
        ownerContainer:AddChild(space)

        local reviewsLabel = AceGUI:Create("Label")
        reviewsLabel:SetText("999 reviews")  -- Placeholder reviews count
        reviewsLabel:SetFontObject(GameFontNormalSmall)
        reviewsLabel:SetColor(0.5, 0.5, 0.5)  -- Gray color
        reviewsLabel:SetWidth(60)
        ownerContainer:AddChild(reviewsLabel)

        header:AddChild(ownerContainer)
        orderGroup:AddChild(header)


        -- Row 1: Icon, item name, price/tip, Accept button
        local row1 = AceGUI:Create("SimpleGroup")
        row1:SetFullWidth(true)
        row1:SetLayout("Flow")

        -- Replace icon and item name with ItemWidget
        local itemWidget, itemNameLabel = ns.CreateItemWidget(row1.frame, "MailItem"..i, {
            labelWidth = 115
        })
        itemWidget:SetPoint("LEFT", row1.frame, "LEFT", 6, 0)

        -- Create a wrapper to add to AceGUI
        local itemContainer = AceGUI:Create("MinimalFrame")
        itemContainer:SetWidth(170)
        itemContainer:SetHeight(40)
        row1:AddChild(itemContainer)

        -- Store references for easy updating
        orderGroup.itemWidget = itemWidget
        orderGroup.itemNameLabel = itemNameLabel

        -- PriceWidget

        local widgetSpace = AceGUI:Create("Label")
        widgetSpace:SetHeight(0)
        widgetSpace:SetWidth(160)

        local priceWidget = ns.CreatePriceWidget(widgetSpace.frame, {
            topPad = -10,
            rightPad = -2,
            width = 160,
        })
        row1:AddChild(widgetSpace)


        local acceptButton = AceGUI:Create("Button")
        acceptButton:SetText("Accept")
        acceptButton:SetWidth(85)
        acceptButton:SetCallback("OnClick", function()
            if not orderGroup.auctionId then
                return
            end

            local auction = ns.AuctionHouseDB.auctions[orderGroup.auctionId]
            if not auction then
                ns.DebugLog("[DEBUG] Auction not found for ID - unexpected!", orderGroup.auctionId)
                return
            end

            local note = orderGroup.noteBox:GetText()
            if not note or note == "" or note == 'Add note ...' then
                note = ""
            end

            local totalCopper = ns.GetExpectedCopperForMail(auction)

            local ok, err = PrefillAuctionMail(totalCopper, auction.quantity, auction.itemID, auction.buyer, note)
            if not ok then
                print(ChatPrefixError() .. " Failed to send mail:", err)

                ClearMailFields()
                self.pendingAuctionId = nil
                return
            end
            self.currentMailCopper = totalCopper

            -- Validate the prefilled mail
            local isValid, validationError = self:ValidateMailForAuction(orderGroup.auctionId, auction.buyer)
            if not isValid then
                print(ChatPrefixError() .. " [ERROR] Validation failed after successful mail prefill:", validationError)

                ClearMailFields()
                self.pendingAuctionId = nil
                return
            end

            self.pendingAuctionId = orderGroup.auctionId
        end)
        row1:AddChild(acceptButton)
        orderGroup:AddChild(row1)

        -- Row 2: Multi-line note
        local row2 = AceGUI:Create("SimpleGroup")
        row2:SetFullWidth(true)
        row2:SetLayout("Flow")

        local noteBox = AceGUI:Create("MultiLineEditBoxCustom")
        noteBox:SetLabel("")
        noteBox:SetFullWidth(true)
        noteBox:SetMaxLetters(225)
        noteBox:DisableButton(true)
        noteBox:SetText("Add note ...")
        noteBox.editBox:SetFontObject(GameFontNormalSmall)
        noteBox.editBox:SetTextColor(1, 1, 1, 0.75)

        -- Clear placeholder text on focus
        noteBox.editBox:SetScript("OnEditFocusGained", function(self)
            if noteBox:GetText() == "Add note ..." then
                noteBox:SetText("")
            end
        end)
        -- Restore placeholder text if empty on focus lost
        noteBox.editBox:SetScript("OnEditFocusLost", function(self)
            if noteBox:GetText() == "" then
                noteBox:SetText("Add note ...")
            end
        end)

        row2:AddChild(noteBox)
        orderGroup:AddChild(row2)

        -- Store references for easy updating
        orderGroup.iconWidget = itemIconWidget
        orderGroup.itemNameLabel = itemNameLabel
        orderGroup.priceWidget = priceWidget
        orderGroup.noteBox = noteBox
        orderGroup.acceptButton = acceptButton

        -- Store additional references for updating
        orderGroup.username = username
        orderGroup.reviewsLabel = reviewsLabel
        orderGroup.starRating = starRating

        -- Add decline button in top-right corner
        local declineButton = CreateFrame("Button", nil, orderGroup.content, "UIPanelCloseButton")
        declineButton:SetSize(20, 20)
        declineButton:SetPoint("TOPRIGHT", 2, 0)
        declineButton:SetScript("OnClick", function()
            if orderGroup.auctionId then
                StaticPopup_Show("GAH_MAIL_CANCEL_AUCTION", nil, nil, {auctionId = orderGroup.auctionId})
            end
        end)

        -- Store reference
        orderGroup.declineButton = declineButton

        return orderGroup
    end

    -- Create and add the static slots
    for i = 1, self.auctionsPerPage do
        local slot = CreateOrderSlot(i)
        if slot then
            slot.content:Hide() -- hidden by default; we'll show/hide as we update
            self.orderSlots[i] = slot
            frame:AddChild(slot)
        else
            print(ChatPrefixError() .. " [ERROR] Failed to create mailbox UI slot", i)
        end
    end

    -- Bottom pagination and action buttons
    local paginationContainer = AceGUI:Create("SimpleGroup")
    paginationContainer:SetFullWidth(true)
    paginationContainer:SetLayout("Flow")
    paginationContainer.content:SetPoint("TOPLEFT", 4, 6)
    paginationContainer.content:SetPoint("BOTTOMRIGHT", -4, 0)
    frame:AddChild(paginationContainer)

    -- Button widths
    local buttonWidth = 65  -- width of pagination buttons
    local actionButtonWidth = 130  -- width of Accept/Decline buttons

    -- Count active buttons
    local numActionButtons = 1 -- Accept All/Decline All hidden
    local numPaginationButtons = 2  -- Previous and Next buttons

    -- Calculate total and spacing
    local totalWidth = 425 - 4 - 4 - 8 - 4  -- total width minus padding from the frame, and padding from paginationContainer itself
    local totalButtonsWidth = (numActionButtons * actionButtonWidth) + (numPaginationButtons * buttonWidth)
    local sideSpacerWidth = (totalWidth - totalButtonsWidth) / 2

    -- Prev button
    local prevButton = AceGUI:Create("Button")
    prevButton:SetText("Prev")
    prevButton:SetWidth(buttonWidth)
    prevButton:SetCallback("OnClick", function()
        if self.currentPage > 1 then
            self.currentPage = self.currentPage - 1
            self:RefreshPage()
        end
    end)
    paginationContainer:AddChild(prevButton)
    self.prevButton = prevButton

    -- Left spacer
    local leftSpacer = AceGUI:Create("Label")
    leftSpacer:SetText("")
    leftSpacer:SetWidth(sideSpacerWidth)
    paginationContainer:AddChild(leftSpacer)

    -- Accept All button
    local acceptAllButton = AceGUI:Create("Button")
    acceptAllButton:SetText("Accept All")
    acceptAllButton:SetWidth(actionButtonWidth)
    acceptAllButton:SetCallback("OnClick", function()
        ns.DebugLog("[DEBUG] Accept All clicked")
    end)
    -- paginationContainer:AddChild(acceptAllButton)  -- hide the button
    self.acceptAllButton = acceptAllButton

    -- Decline All button
    local declineAllButton = AceGUI:Create("Button")
    declineAllButton:SetText("Decline All")
    declineAllButton:SetWidth(actionButtonWidth)
    declineAllButton:SetCallback("OnClick", function()
        StaticPopup_Show("OF_DECLINE_ALL")
    end)
    paginationContainer:AddChild(declineAllButton)  -- hide the button
    self.declineAllButton = declineAllButton

    -- right spacer
    local leftSpacer = AceGUI:Create("Label")
    leftSpacer:SetText("")
    leftSpacer:SetWidth(sideSpacerWidth)
    paginationContainer:AddChild(leftSpacer)

    -- Next button
    local nextButton = AceGUI:Create("Button")
    nextButton:SetText("Next")
    nextButton:SetWidth(buttonWidth)
    nextButton:SetCallback("OnClick", function()
        local allAuctions = ns.AuctionHouseAPI:GetMySellPendingAuctions()
        local totalAuctions = 0
        for _ in pairs(allAuctions) do
            totalAuctions = totalAuctions + 1
        end

        local totalPages = math.ceil(totalAuctions / self.auctionsPerPage)
        if self.currentPage < totalPages then
            self.currentPage = self.currentPage + 1
            self:RefreshPage()
        end
    end)
    paginationContainer:AddChild(nextButton)
    self.nextButton = nextButton

    -- Store references
    self.mailboxUI = frame

    -- Register for auction updates
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, function()
        if self.mailboxUI and self.mailboxUI:IsShown() then
            self:RefreshOrders()
        end
    end)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, function()
        if self.mailboxUI and self.mailboxUI:IsShown() then
            self:RefreshOrders()
        end
    end)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, function()
        if self.mailboxUI and self.mailboxUI:IsShown() then
            self:RefreshOrders()
        end
    end)
end

-- Updates a single slot (icon, name, price, tip, etc.)
function MailboxUI:UpdateSlot(slotIndex, auction)
    local slot = self.orderSlots[slotIndex]
    if not slot then return end

    if not auction then
        -- Hide unused slot
        slot:HideSlot()
        slot.auctionId = nil
        return
    end

    -- Reset note box to default state
    -- placeholder, will be overwritten when you click the box
    local noteText = "Add note ..."
    if auction.raidAmount and auction.raidAmount > 0 then
        noteText = "You promised to raid twitch.tv/" .. ns.GetTwitchName(auction.owner) .. " for this item"
    end
    slot.noteBox:SetText(noteText)

    -- Check if player has enough items
    local playerItemCount = ns.GetItemCount(auction.itemID)
    local hasEnoughItems = playerItemCount >= auction.quantity
    local ratingAvg, ratingCount = ns.AuctionHouseAPI:GetAverageRatingForUser(auction.buyer)

    -- Disable accept button if not enough items
    slot.acceptButton:SetDisabled(not hasEnoughItems)

    -- Update accept button text based on auction type
    slot.acceptButton:SetText(auction.status == ns.AUCTION_STATUS_PENDING_LOAN and "Loan" or "Accept")

    -- Update owner info
    slot.username:SetText(ns.GetDisplayName(auction.buyer) or "Unknown")
    slot.starRating:SetRating(ratingAvg)
    slot.reviewsLabel:SetText(string.format("%d reviews", ratingCount))

    slot:ShowSlot()
    slot.auctionId = auction.id

    slot.itemWidget:SetItem(auction.itemID, auction.quantity)
    slot.priceWidget:UpdateView(auction)
end

-- Called whenever anything changes that might need a re-draw of the visible items
function MailboxUI:RefreshPage()
    if not self.orderSlots then return end

    local allAuctions = ns.AuctionHouseAPI:GetMySellPendingAuctions()
    local auctionsList = {}
    for id, auction in pairs(allAuctions) do
        -- we don't shown spells in the mailbox as you can't send them
        local isSupported = auction.itemID and not ns.IsSpellItem(auction.itemID)
        -- Only include auctions that allow mail delivery
        local isDeliveryMatch = (
            auction.deliveryType == ns.DELIVERY_TYPE_ANY or
            auction.deliveryType == ns.DELIVERY_TYPE_MAIL
        )

        if isSupported and isDeliveryMatch then
            table.insert(auctionsList, auction)
        end
    end
    table.sort(auctionsList, function(a, b) return (a.id < b.id) end)

    -- Show/hide "No Pending Orders" message and disable/enable buttons based on auctions count
    local hasAuctions = #auctionsList > 0

    if self.acceptAllButton then
        self.acceptAllButton:SetDisabled(not hasAuctions)
    end
    if self.declineAllButton then
        self.declineAllButton:SetDisabled(not hasAuctions)
    end

    -- Rest of the existing refresh logic
    local totalAuctions = #auctionsList
    local totalPages = math.ceil(totalAuctions / self.auctionsPerPage)

    -- Disable/enable prev button
    if self.prevButton then
        self.prevButton:SetDisabled(self.currentPage <= 1)
    end

    -- Disable/enable next button
    if self.nextButton then
        self.nextButton:SetDisabled(self.currentPage >= totalPages)
    end

    local startIndex = (self.currentPage - 1) * self.auctionsPerPage + 1

    for slotIndex = 1, self.auctionsPerPage do
        local auction = auctionsList[startIndex + slotIndex - 1]
        self:UpdateSlot(slotIndex, auction)
    end

    if hasAuctions then
        self.noOrdersLabel.label:Hide()
    else
        self.noOrdersLabel.label:Show()
    end
end

-- RefreshOrders calls RefreshPage without rebuilding UI
function MailboxUI:RefreshOrders()
    if not self.mailboxUI then return end
    self:RefreshPage()
end

-- 'OnAttemptSendMail' is the most reliable way to get currentRecipient
function MailboxUI:OnAttemptSendMail(recipient, subject, body)
    if self.pendingAuctionId then
        self.currentRecipient = recipient
    end
end

function MailboxUI:OnTakeInboxItem(index, itemSlot)
    local packageIcon, stationeryIcon, sender, subject,
          money, CODAmount, daysLeft, quantity, wasRead,
          wasReturned, textCreated, canReply = GetInboxHeaderInfo(index)

    local itemName, itemID, itemTexture, itemQuantity, quality, canUse = GetInboxItem(index, itemSlot)
    -- local itemLink = GetInboxItemLink(index, itemSlot)

    if wasReturned then
        return -- Not a successful trade
    end

    -- Try to complete any matching auctions
    ns.AuctionHouseAPI:TryCompleteItemTransfer(
        sender,  -- seller
        UnitName("player"),  -- buyer/recipient
        {{itemID = itemID, count = itemQuantity}},
        CODAmount or 0,

        -- type info
        ns.DELIVERY_TYPE_MAIL
    )
end

-- NOTE: we can't distinguish here between:
--   * collecting COD money (the other person got an item & paid, and now we're collecting the money)
--   * collecting gold (in case you were asking for gold)
--
-- when both cases above exist, the right auction might not be chosen
function MailboxUI:OnTakeInboxMoney(index)
    local packageIcon, stationeryIcon, sender, subject,
          money, CODAmount, daysLeft, quantity, wasRead,
          wasReturned, textCreated, canReply = GetInboxHeaderInfo(index)

    if wasReturned then
        ns.DebugLog("OnTakeInboxMoney wasReturned")
        return -- Not a successful trade
    end
    if money <= 0 then
        ns.DebugLog(string.format("OnTakeInboxMoney money <= 0: %d", money))
        return
    end

    ns.DebugLog(string.format(
        "OnTakeInboxMoney try complete transfer. sender: %s, money: %d",
        sender, money
    ))

    -- Try to complete any matching auctions
    ns.AuctionHouseAPI:TryCompleteItemTransfer(
        sender,  -- seller
        UnitName("player"),  -- buyer/recipient
        {{itemID = ns.ITEM_ID_GOLD, count = money}},
        money,  -- money transferred

        -- type info
        ns.DELIVERY_TYPE_MAIL
    )
end


function MailboxUI:Initialize()
    -- Add tracking state
    self.currentMailItems = {}
    self.currentMailCopper = 0
    self.currentRecipient = nil
    self.pendingAuctionId = nil

    -- Register existing events
    self:RegisterEvent("MAIL_SHOW", "OnMailShow")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "OnFrameHide")
    self:RegisterEvent("MAIL_SEND_SUCCESS", "OnMailSendSuccess")
    self:RegisterEvent("MAIL_SEND_INFO_UPDATE", "OnMailSendInfoUpdate")

    MoneyInputFrame_SetOnValueChangedFunc(SendMailMoney, function()
        self:OnMailSendInfoUpdate()
        SendMailFrame_CanSend()
    end)

	hooksecurefunc("SendMail", function(recipient, subject, body)
		self:OnAttemptSendMail(recipient, subject, body)
	end)


	local function GetItemFromMail(MailIndex, ItemIndex)
		-- print("[DEBUG] TakeInboxItem hook called:", MailIndex, ItemIndex)
		self:OnTakeInboxItem(MailIndex, ItemIndex)
	end

	hooksecurefunc("TakeInboxItem", GetItemFromMail)

	local function GetMoneyFromMail(index)
		-- print("[DEBUG] TakeInboxItem hook called:", index)
		self:OnTakeInboxMoney(index)
	end

	hooksecurefunc("TakeInboxMoney", GetMoneyFromMail)


	local function GetAutoMailInfo(MailIndex)
		-- print("[DEBUG] AutoLootMailItem hook called:", MailIndex)
		for i = 1, 12 do
			if GetInboxItem(MailIndex, i) then
				ns.DebugLog("[DEBUG] Found item in slot", i)
				self:OnTakeInboxItem(MailIndex, i)
			end
		end
	end

	hooksecurefunc("AutoLootMailItem", GetAutoMailInfo)

    -- Listen for newly cached item info so we can refresh text/icons
    local f = CreateFrame("Frame")
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:SetScript("OnEvent", function(_, _, receivedItemID)
        if self.mailboxUI and self.mailboxUI:IsShown() then
            self:RefreshOrders()
        end
    end)
end


-- MAIL_SEND_INFO_UPDATE | SEND_MAIL_COD_CHANGED
-- one of the details of the mail was updated
function MailboxUI:OnMailSendInfoUpdate()
    -- Clear current state
    wipe(self.currentMailItems)

    -- Store current recipient
    self.currentRecipient = SendMailNameEditBox:GetText()

    -- Check each attachment slot
    for i = 1, ATTACHMENTS_MAX_SEND do
        if HasSendMailItem(i) then
            local itemName, itemID, _, stackCount, _ = GetSendMailItem(i)
            self.currentMailItems[i] = {
                name = itemName,
                id = itemID,
                count = stackCount,
            }
        end
    end

    -- Get money amount
    self.currentMailCopper = MoneyInputFrame_GetCopper(SendMailMoney)

    if self.currentMailCopper > 10000 * 100 * 100 then
        self.currentMailCopper = 10000 * 100 * 100  -- avoid overflow errors elsewhere. COD mail doesnt support it anyway
    end
end

-- Helper function to print current mail state
function MailboxUI:DebugPrintMailState()
    local output = string.format("COD Copper: %d", self.currentMailCopper)

    for slot, item in pairs(self.currentMailItems) do
        output = output .. string.format(" | Slot %d: %s x%d",
            slot,
            item.name or "unknown",
            item.count or 1
        )
    end

    print("[DEBUG]" .. output)
end

-- Update OnMailSendSuccess to use the new validation function
function MailboxUI:OnMailSendSuccess()
    if self.pendingAuctionId then
        local isValid, err = self:ValidateMailForAuction(self.pendingAuctionId)
        if isValid then
            local auction = ns.AuctionHouseDB.auctions[self.pendingAuctionId]
            local newStatus = ""
            if auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
                newStatus = ns.AUCTION_STATUS_SENT_LOAN 
            else
                newStatus = ns.AUCTION_STATUS_SENT_COD
            end

            ns.AuctionHouseAPI:UpdateAuctionStatus(self.pendingAuctionId, newStatus)
            print(ChatPrefix() .. " Mail successfully sent")
        else
            print(ChatPrefixError() .. " Mail didn't match auction and is not being tracked:", err)
        end
    end

    -- Clear state
    self.pendingAuctionId = nil
    wipe(self.currentMailItems)
    self.currentMailCopper = 0
    self.currentRecipient = nil
end

function MailboxUI:OnMailShow()
    self:CreateMailboxUI()
    self:OnMailSendInfoUpdate()

    if self.mailboxUI then
        self:RefreshOrders()
        OFAuctionFrame:Hide()
        self.mailboxUI:Show()
    end
end

function MailboxUI:OnFrameHide(event, interactionType)
    if interactionType == Enum.PlayerInteractionType.MailInfo then
        if self.mailboxUI then
            self.mailboxUI:Hide()
        end

        self:OnMailSendInfoUpdate()
    end
end

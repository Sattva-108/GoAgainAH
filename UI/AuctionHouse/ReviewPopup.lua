local addonName, ns = ...
local L = ns.L
local AceGUI = LibStub("AceGUI-3.0")

local PaneBackdrop  = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 5, bottom = 2 }
}

local REVIEW_PLACEHOLDER = L["Write your review ..."]

local function CreateBorderedGroup(relativeWidth, height)
    local group = AceGUI:Create("MinimalFrame")
    group:SetRelativeWidth(relativeWidth)
    group:SetLayout("Flow")

    if height then
        group:SetHeight(height)
    end

    local border = CreateFrame("Frame", nil, group.frame)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetBackdrop(PaneBackdrop)
    border:SetBackdropColor(0.15, 0.15, 0.13, 1) -- #272522
    border:SetBackdropBorderColor(0.4, 0.4, 0.4)

    return group
end

local function CreateInfoContainer()
    local root = AceGUI:Create("SimpleGroup")
    root:SetFullWidth(true)
    root:SetLayout("Flow")
    root:SetHeight(80)

    local priceGroup = CreateBorderedGroup(0.455, 42)
    priceGroup:SetPadding(12, 4)
    root:AddChild(priceGroup)

    local priceWidget = ns.CreatePriceWidget(priceGroup.frame, {
        topPad = 4,
    })
    -- priceGroup:AddChild(priceWidget.aceFrame)

    local middleArrowGroup = AceGUI:Create("MinimalFrame")
    middleArrowGroup:SetRelativeWidth(0.09)
    middleArrowGroup:SetLayout("Flow")
    middleArrowGroup:SetHeight(42)

    -- Add arrow icon
    local swapArrows = AceGUI:Create("Icon")
    swapArrows:SetImage("Interface\\AddOns\\\" .. addonName .. \"\\Media\\Icons\\Icn_SwapArrow.tga")
    swapArrows:SetImageSize(22, 22)
	swapArrows.image:ClearAllPoints()
	swapArrows.image:SetPoint("TOP", 0, -8)
    middleArrowGroup:AddChild(swapArrows)

    root:AddChild(middleArrowGroup)

    local itemGroup = CreateBorderedGroup(0.455, 42)
    root:AddChild(itemGroup)

    -- Create a container frame for the item widget
    local itemContainer = CreateFrame("Frame", nil, itemGroup.frame)
    itemContainer:SetPoint("TOPLEFT", 0, -5)
    itemContainer:SetPoint("BOTTOMRIGHT", -5, 5)

    local itemWidget, itemNameLabel = ns.CreateItemWidget(itemContainer, "ReviewPopupItem", {
        labelWidth = itemGroup.frame:GetWidth() - 18,  -- Container width minus padding
    })
    itemWidget:SetPoint("LEFT", 0, 0)

    return {
        infoContainer = root,
        priceWidget = priceWidget,
        itemWidget = itemWidget
    }
end

local function CreateReviewPrompt()
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle(L["Write Review"])
    frame:SetLayout("Flow")
    frame:SetWidth(410)
    frame:SetHeight(400)

    -- Close button
    local closeButton = CreateFrame("Button", "GoAHExitButton", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7, 7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    -- Add top padding
    local topPadding = AceGUI:Create("SimpleGroup")
    topPadding:SetFullWidth(true)
    topPadding:SetHeight(4)
    frame:AddChild(topPadding)

    local info = CreateInfoContainer()
    frame:AddChild(info.infoContainer)

    -- Add padding between info and review group
    local middlePadding = AceGUI:Create("MinimalFrame")
    middlePadding:SetFullWidth(true)
    middlePadding:SetHeight(8)
    frame:AddChild(middlePadding)

    ----------------------------------------------------------------------------
    -- Review Group
    ----------------------------------------------------------------------------
    local reviewGroup = CreateBorderedGroup(1, 230)
    reviewGroup:SetPadding(10, 15)
    frame:AddChild(reviewGroup)

    -- Static label
    local staticLabel = AceGUI:Create("Label")
    staticLabel:SetFontObject(GameFontNormal)
    local msg = L["Write your review for"]
    staticLabel:SetText(string.format("|cFFFFD100%s|r", msg))
    staticLabel:SetHeight(16)
    reviewGroup:AddChild(staticLabel)

    -- Add padding between label and name
    local labelPadding = AceGUI:Create("MinimalFrame")
    labelPadding:SetFullWidth(true)
    labelPadding:SetHeight(2)
    reviewGroup:AddChild(labelPadding)

    -- Target name label
    local targetLabel = AceGUI:Create("Label")
    targetLabel:SetFontObject(GameFontNormal)
    targetLabel:SetHeight(20)
    targetLabel:SetFullWidth(true)
    reviewGroup:AddChild(targetLabel)

    local submitButton = AceGUI:Create("Button")
    submitButton:SetText(L["Submit Review"])
    submitButton:SetFullWidth(true)
    submitButton:SetHeight(40)
    submitButton:SetDisabled(true)

    -- Add padding between name and star
    local labelPadding = AceGUI:Create("MinimalFrame")
    labelPadding:SetFullWidth(true)
    labelPadding:SetHeight(10)
    reviewGroup:AddChild(labelPadding)

    -- Star rating
    local starRating = ns.CreateStarRatingWidget({
        interactive = true,
        onChange = function(rating)
            submitButton:SetDisabled(rating == 0)
        end,
        useGreyStars = true,
        panelHeight = 42,
        hitboxPadY = 30,
        hitboxPadX = 6,
        textWidth = 26,
        labelFont = "GameFontNormalLarge",
    })
    reviewGroup:AddChild(starRating)

    -- Comment box
    local reviewEdit = AceGUI:Create("MultiLineEditBoxCustom")
    reviewEdit:SetLabel("")
    reviewEdit:SetFullWidth(true)
    reviewEdit:DisableButton(true)
    reviewEdit:SetMaxLetters(90+45)
    reviewEdit:SetNumLines(6)
    reviewEdit:SetHeight(115)
    reviewEdit.editBox:SetFontObject(GameFontNormal)
    reviewEdit.editBox:SetTextColor(1, 1, 1, 0.75)

    -- Clear placeholder text on focus
    reviewEdit.editBox:SetScript("OnEditFocusGained", function(self)
        if reviewEdit:GetText() == REVIEW_PLACEHOLDER then
            reviewEdit:SetText("")
        end
    end)
    -- Restore placeholder text if empty on focus lost
    reviewEdit.editBox:SetScript("OnEditFocusLost", function(self)
        if reviewEdit:GetText() == "" then
            reviewEdit:SetText(REVIEW_PLACEHOLDER)
        end
    end)

    reviewGroup:AddChild(reviewEdit)

    -- Add padding between info and review group
    local bottomPadding = AceGUI:Create("MinimalFrame")
    bottomPadding:SetFullWidth(true)
    bottomPadding:SetHeight(10)
    frame:AddChild(bottomPadding)

    -- Submit Button
    frame:AddChild(submitButton)


    -- Collect references for later access
    local prompt = {
        frame = frame,
        closeButton = closeButton,
        priceWidget = info.priceWidget,
        itemWidget = info.itemWidget,
        targetLabel = targetLabel,
        starRating = starRating,
        reviewEdit = reviewEdit,
        submitButton = submitButton
    }

    ----------------------------------------------------------------------------
    -- Show / Hide
    ----------------------------------------------------------------------------
    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    end

    ----------------------------------------------------------------------------
    -- Setters
    ----------------------------------------------------------------------------
    function prompt:SetItem(itemID, count)
        self.itemWidget:SetItem(itemID, count)
    end

    function prompt:SetTargetName(name)
        self.targetLabel:SetText(name)
    end

    function prompt:SetPriceInfo(auction)
        self.priceWidget:UpdateView(auction)
    end

    ----------------------------------------------------------------------------
    -- Callbacks
    ----------------------------------------------------------------------------
    function prompt:OnSubmit(callback)
        self.submitButton:SetCallback("OnClick", function()
            callback(self.starRating.rating, self.reviewEdit:GetText())
        end)
    end

    function prompt:OnCancel(callback)
        self.closeButton:SetScript("OnClick", function()
            self.frame:Hide()
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
            callback()
        end)
    end

    return prompt
end

-- Create a singleton instance
local reviewPrompt

local function GetReviewPrompt()
    if not reviewPrompt then
        reviewPrompt = CreateReviewPrompt()
    end
    return reviewPrompt
end

function ns.ShowReviewPopup(trade, overrideUser)
    if not trade then
        print(ChatPrefixError() .. " Warning: failed to open review popup, missing trade")
        return
    end
    if not trade.id then
        print(ChatPrefixError() .. " Warning: failed to open review popup, missing trade ID")
        return
    end

    local me = overrideUser or UnitName("player")

    local auction = trade.auction
    local otherUser = auction.owner == me and auction.buyer or auction.owner
    local isSeller = auction.owner == me

    local hasExistingReview, existingRating, existingText
    if isSeller then
        hasExistingReview = trade.sellerText
        existingRating = trade.sellerRating
        existingText = trade.sellerText
    else
        hasExistingReview = trade.buyerText
        existingRating = trade.buyerRating
        existingText = trade.buyerText
    end

    local prompt = GetReviewPrompt()

    -- Reset the form
    prompt.starRating:SetRating(existingRating or 0)
    prompt.reviewEdit:SetText(existingText or REVIEW_PLACEHOLDER)

    -- Reset button state
    prompt.submitButton:SetDisabled((existingRating or 0) == 0)
    local submitText
    if hasExistingReview then
        submitText = L["Update Review"]
    else
        submitText = L["Submit Review"]
    end
    prompt.submitButton:SetText(submitText)

    -- Update the display
    prompt:SetItem(auction.itemID, auction.quantity)
    prompt:SetTargetName(ns.GetDisplayName(otherUser))
    prompt:SetPriceInfo(auction)

    prompt:OnSubmit(function(rating, text)
        local finalText = text == REVIEW_PLACEHOLDER and "" or text
        local _, err = nil, nil

        if isSeller then
            _, err = ns.AuctionHouseAPI:SetSellerReview(trade.id, {
                rating = rating or 1,
                text = finalText or "",
            })
        else
            _, err = ns.AuctionHouseAPI:SetBuyerReview(trade.id, {
                rating = rating or 1,
                text = finalText or "",
            })
        end

        if err then
            print(ChatPrefixError() .. " Failed to submit review: " .. err)
        else
            -- print(ChatPrefix() .. " |cffffcc00Review submitted successfully|r")
        end

        prompt:Hide()
    end)

    prompt:OnCancel(function()
        -- Optional cancel callback
    end)

    prompt:Show()
end

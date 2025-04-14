local addonName, ns = ...
local L = ns.L

local OF_REVIEWS_PER_PAGE = 15
local REVIEWS_IN_1_SCREEN = 3
local REVIEW_HEIGHT = 142

local TAB_MY_REVIEWS = 1
local TAB_RECENT_REVIEWS = 2
local TAB_LEADERBOARD = 3

ns.REVIEW_TABS = {
    { name = L["My Reviews"], id = TAB_MY_REVIEWS },
    { name = L["Recent Reviews"], id = TAB_RECENT_REVIEWS },
    { name = L["Leaderboard"], id = TAB_LEADERBOARD, disabled = true },
}

StaticPopupDialogs["OF_LEAVE_REVIEW"] = {
    text = L["Auction completed successfully!\nWrite your review"],
    button1 = L["Write Review"],
    button2 = L["Do it later"],
    OnAccept = function(self, data)
        -- Start the review process with the provided tradeID
        local trade = ns.AuctionHouse.db.trades[data.tradeID]
        ns.ShowReviewPopup(trade)
    end,
    showAlert = 0,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
    enterClicksFirstButton = 1,
};

local function FormatTimeAgo(timestamp)
    if not timestamp or timestamp == 0 then
        return ""
    end

    local diff = time() - timestamp
    if diff < 0 then
        diff = 0
    end

    local seconds = diff
    local minutes = math.floor(diff / 60)
    local hours   = math.floor(diff / 3600)
    local days    = math.floor(diff / 86400)
    local weeks   = math.floor(diff / 604800)
    local months  = math.floor(diff / 2592000)
    local years   = math.floor(diff / 31536000)

    local num, format
    if years > 0 then
        num = years
        format = L["%dy ago"]
    elseif months > 0 then
        num = months
        format = L["%dmo ago"]
    elseif weeks > 0 then
        num = weeks
        format = L["%dw ago"]
    elseif days > 0 then
        num = days
        format = L["%dd ago"]
    elseif hours > 0 then
        num = hours
        format = L["%dh ago"]
    elseif minutes > 0 then
        num = minutes
        format = L["%dm ago"]
    else
        num = seconds
        format = L["%ds ago"]
    end

    return string.format(format, num)
end

local function GetReviews(selectedTab)
    local trades = {}
    if selectedTab == TAB_MY_REVIEWS then
        trades = ns.AuctionHouseAPI:GetMyTrades()
    elseif selectedTab == TAB_RECENT_REVIEWS then
        trades = ns.AuctionHouseAPI:GetTrades()
    end

    local results = {}

    for _, trade in ipairs(trades) do
        local tradeComplete = ns.AuctionHouseAPI:IsTradeCompleted(trade)
        local includeTrade = true
        if selectedTab == TAB_RECENT_REVIEWS and not tradeComplete then
            includeTrade = false
        end

        if includeTrade then
            -- If the auction is completed or has a valid completeAt
            local auction = trade.auction
            -- NOTE: OnlyFangsRaceMap was only added to onlyfangs on dec 24
            -- so the race might not be available if the user's OnlyFangs addon is out of date,
            -- but it's the best we can do easily
            local sellerDisplayName = ns.GetDisplayName(auction.owner, 'left') or L["Unknown"]
            local buyerDisplayName = ns.GetDisplayName(auction.buyer, 'right') or L["Unknown"]

            table.insert(results, {
                trade = trade,
                auction = auction,
                completeAt = auction.completeAt or 0,

                -- item info
                itemID            = auction.itemID,

                -- left side is always seller
                leftReviewerName  = auction.owner,
                leftReviewer      = sellerDisplayName,
                leftReviewerDead  = trade.sellerDead,
                leftRating        = trade.sellerRating,
                leftText          = trade.sellerText,

                -- right side is always buyer
                rightReviewerName = auction.buyer,
                rightReviewer     = buyerDisplayName,
                rightReviewerDead = trade.buyerDead,
                rightRating       = trade.buyerRating,
                rightText         = trade.buyerText,

                -- price info
                price             = auction.price or 0,
                tip               = auction.tip or 0,
                priceType         = auction.priceType,
                raidAmount        = auction.raidAmount or 0,

                -- how long ago it completed
                timeAgo           = FormatTimeAgo(auction.completeAt)
            })
        end
    end

    -- Sort results by completeAt in descending order
    table.sort(results, function(a, b)
        return (a.completeAt or 0) > (b.completeAt or 0)
    end)

    return results
end

local function GetMockReviews()
    local baseData = {
        {
            -- Left side
            itemID = 19018,
            itemCount = 1,
            leftReviewer = GetRaceIcon("Undead") .. " Raider",
            leftRating = 5,
            leftText = "Best weapon for AoE farming",
            timeAgo = "3m ago",

            -- Right side
            rightReviewer = "Hypez  " .. GetRaceIcon("Orc"),
            rightRating = 5,
            rightText = "Massive views, not botted",
            price = 0,
            tip = 0,
            priceType = ns.PRICE_TYPE_TWITCH_RAID,
            raidAmount = 100,
        },
        {
            -- Left side (item review)
            itemID = 159,
            itemCount = 20,
            leftReviewer = GetRaceIcon("Troll") .. " Alice",
            leftRating = 3,
            leftText = "was fine",
            timeAgo = "2h ago",

            -- Right side (price review)
            rightReviewer = "Bob  " .. GetRaceIcon("Troll"),
            rightRating = 5,
            rightText = "Fair price for H2O. such a deal. much wow. no scammaz. poggers. Fair price for H2O. such a deal. much wow. no scammaz. poggers. OOOO OOOO OOOO OOOO OOOO OOOO OOOO OOOO OOOO OOOO OOOO OOOO",
            price = 1500,
            tip = 150,
            priceType = ns.PRICE_TYPE_MONEY,
        },
        {
            -- Left side
            itemID = 19019,
            itemCount = 1,
            leftReviewer = GetRaceIcon("Tauren") .. " Warrior123",
            leftRating = 3,
            leftText = "Decent stats but not best in slot",
            timeAgo = "99d ago",

            -- Right side
            rightReviewer = "AHMaster  " .. GetRaceIcon("Undead"),
            rightRating = 2,
            rightText = "rude and no tip",
            price = 99996901,
            tip = 1,
            priceType = ns.PRICE_TYPE_MONEY,
        },
    }

    local mockData = {}
    -- Loop the base data until we have 20 entries
    for i = 1, 25 do
        local baseIndex = ((i-1) % #baseData) + 1
        local entry = CopyTable(baseData[baseIndex])
        -- Modify the timeAgo and add index to reviewer name
        entry.timeAgo = i .. "h ago"
        entry.leftReviewer = entry.leftReviewer .. " " .. i
        table.insert(mockData, entry)
    end

    return mockData
end

function AHReviewButton_SetUp(button, info)
    -- Set up the button appearance
    button:SetText(info.name);

    -- Set up the texture
    local tex = button:GetNormalTexture();
    tex:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg");
    tex:SetTexCoord(0, 0.53125, 0, 0.625);
end

function OFAuctionFrameReviews_SelectTab(tabID)
    local self = OFAuctionFrameReviews
    if not self then return end

    self.selectedTab = tabID

    -- Update tab highlights
    for i, buttonInfo in ipairs(ns.REVIEW_TABS) do
        local button = _G["AHReview"..i]
        if button then
            if buttonInfo.id == tabID then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    -- Refresh the view
    OFReviewBrowse_Update()
end

-- text in the left bar of tabs,
-- shows eg 'My Reviews (2)' when there are 2 reviews pending
local function UpdateMyReviewsText()
    local self = OFAuctionFrameReviews
    if not self then return end

    local tabText
    local pendingReviews = ns.AuctionHouseAPI:GetPendingReviewCount()
    if pendingReviews > 0 then
         tabText = string.format(L["My Reviews (%d)"], pendingReviews)
    else
         tabText = L["My Reviews"]
    end

    -- Update tab highlights
    for i, _ in ipairs(ns.REVIEW_TABS) do
        if i == TAB_MY_REVIEWS then
            local buttonText = _G["AHReview"..i.."NormalText"]
            if buttonText then
                buttonText:SetText(tabText)
                break
            end
        end
    end
end

function OFAuctionFrameReviews_Initialize()
    local function Update()
        if OFAuctionFrameReviews and OFAuctionFrameReviews:IsShown() then
            OFReviewBrowse_Update()
        end
        OFAuctionFrame_UpdateReviewsTabText()
        UpdateMyReviewsText()
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_TRADE_ADD_OR_UPDATE, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_TRADE_DELETED, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_TRADE_STATE_UPDATE, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_RATING_ADD_OR_UPDATE, Update)
end

local function InitializeLeftTabs(self, tabs)
    for i, buttonInfo in ipairs(tabs) do
        local button = _G["AHReview"..i]
        if button then
            buttonInfo.button = button
            AHReviewButton_SetUp(button, buttonInfo)

            -- Set up click handler
            button:SetScript("OnClick", function()
                if buttonInfo.disabled then
                    return
                end
                OFAuctionFrameReviews_SelectTab(buttonInfo.id)
            end)

            if buttonInfo.id == self.selectedTab then
                button:LockHighlight();
            else
                button:UnlockHighlight();
            end

            -- support disabled buttons
            if buttonInfo.disabled then
                button:Disable()
                button:GetFontString():SetTextColor(0.75, 0.75, 0.75)
            end
        end
    end
end

function OFAuctionFrameReviews_OnLoad_Impl(self)
    self.selectedTab = TAB_RECENT_REVIEWS

    -- update time remaining and time ago
    self.updateTimer = C_Timer:NewTicker(59, function()
        if self:IsShown() then
            OFReviewBrowse_Update()
        end
    end)

    -- Create main container frame with proper insets
    self.container = CreateFrame("Frame", nil, self)
    -- anchors for 'bid frame' layout
    self.container:SetPoint("TOPLEFT", 11, -73)
    self.container:SetPoint("BOTTOMRIGHT", -11, 30)

    -- Set up left-column navigation buttons
    InitializeLeftTabs(self, ns.REVIEW_TABS)

    -- Create the main scroll, for layout
    local scrollFrame = CreateFrame("ScrollFrame", "OFReviewScrollFrame", self.container, "FauxScrollFrameTemplate")
    scrollFrame:SetSize(605, 332)
    scrollFrame:SetPoint("TOPRIGHT", 52, -4)

    -- Actual contents
    local reviews = CreateFrame("Frame", nil, scrollFrame)
    reviews:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    reviews:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 0)
    -- Set a minimum height that will grow as we add cards
    reviews:SetHeight(1)
    reviews:SetWidth(610)

    scrollFrame:SetScrollChild(reviews)

    OFReviewScrollFrame = scrollFrame
	FauxScrollFrame_SetOffset(OFReviewScrollFrame, 0);
    OFAuctionFrameReviews.reviewScrollContent = reviews

    -- Create exactly 10 review card frames (one time), keep them for reuse
    reviews.cards = {}
    for i = 1, OF_REVIEWS_PER_PAGE do
        local card = CreateReviewCard(reviews, i)
        card:Hide()
        table.insert(reviews.cards, card)
    end


    -- scroll bar
    local topTexture = scrollFrame:CreateTexture(nil, "BACKGROUND")
    topTexture:SetSize(30, 256)
    topTexture:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -2, 5)
    topTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    topTexture:SetTexCoord(0, 0.484375, 0, 1)

    local bottomTexture = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bottomTexture:SetSize(30, 106)
    bottomTexture:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -2, -2)
    bottomTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    bottomTexture:SetTexCoord(0.515625, 1, 0, 0.4140625)

    -- mousewheel support
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, REVIEW_HEIGHT, OFReviewBrowse_Update)
    end)
end

local function UpdateItemIcon(buttonName, texture, count, canUse)
    local iconTexture = _G[buttonName.."IconTexture"];
    iconTexture:SetTexture(texture);
    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    end

    local itemCount = _G[buttonName.."Count"];
    if ( count > 1 ) then
        itemCount:SetText(count);
        itemCount:Show();
    else
        itemCount:Hide();
    end
end

local function CreateUserPanel(parent, isRight)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(28)
    panel:SetPoint("TOPLEFT")
    panel:SetPoint("TOPRIGHT")

    local userName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    userName:SetPoint(isRight and "RIGHT" or "LEFT")
    userName:SetTextColor(1, 1, 1)
    -- Add width limit to prevent text overflow
    userName:SetWidth(panel:GetWidth() - 17)
    userName:SetWordWrap(false)
    userName:SetJustifyH(isRight and "RIGHT" or "LEFT")

    return panel, userName
end

local function CreateContentPanel(parent, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(height)
    panel:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -3)
    panel:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -3)

    -- Dark background texture
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetVertexColor(0.051, 0.051, 0.051, 1)

    return panel
end

local function CreateRatingPanel(parent, isRight)
    local margin = 6
    if isRight then
        margin = -6
    end

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(18)
    panel:SetPoint("TOPLEFT", margin, -3)
    panel:SetPoint("TOPRIGHT", margin, -3)

    -- Create star rating widget
    local starConfig = {
        panelHeight = 18,
        starSize = 10,
        marginBetweenStarsX = 2,
        textWidth = 24,
        leftMargin = 1,
    }

    local starWidget = ns.CreateStarRatingWidget(starConfig)
    starWidget.frame:SetParent(panel)
    starWidget.frame:ClearAllPoints()
    if isRight then
        starWidget.frame:SetPoint("RIGHT", 0, 0)
    else
        starWidget.frame:SetPoint("LEFT", 4, 0)
    end

    return panel, starWidget
end

-- Helper function to create the action container, which includes the review text, "time remaining" label,
-- and the corresponding button. This single function can create either a left-aligned or right-aligned panel
-- based on the isRight boolean.
local function CreateActionContainer(parent, anchorPanel, card, isRight)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(22)
    container:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 4, -4)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Center-align timeRemainingText
    local timeRemainingText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeRemainingText:SetText("24h left")
    timeRemainingText:SetPoint("TOP", container, "TOP", 0, 0)
    timeRemainingText:SetTextColor(0.5, 0.5, 0.5)

    -- The main review text
    local reviewText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reviewText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    reviewText:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    reviewText:SetJustifyV("TOP")
    reviewText:SetWordWrap(true)
    reviewText:SetTextColor(1, 1, 1)

    -- The button (varies in alignment and label)
    local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    button:SetSize(100, 22)

    -- Create skull icon
    local skullIcon = container:CreateTexture(nil, "ARTWORK")
    skullIcon:SetSize(22, 22)
    skullIcon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Icons\\Icn_Skull.tga")
    skullIcon:Hide() -- Hidden by default

    if isRight then
        reviewText:SetJustifyH("RIGHT")

        button:SetPoint("LEFT", container, "TOPLEFT", 10, -5)
        button:SetText("")

        -- Position skull at same spot as button
        skullIcon:SetPoint("LEFT", container, "TOPLEFT", 10, -5)

        card.timeRemainingTextRight = timeRemainingText
        card.reviewTextRight = reviewText
        card.reviewButtonRight = button
        card.skullIconRight = skullIcon
    else
        reviewText:SetJustifyH("LEFT")

        button:SetPoint("RIGHT", container, "TOPRIGHT", -5, -5)
        button:SetText("")

        -- Position skull at same spot as button
        skullIcon:SetPoint("RIGHT", container, "TOPRIGHT", -5, -5)

        card.timeRemainingTextLeft = timeRemainingText
        card.reviewTextLeft = reviewText
        card.reviewButtonLeft = button
        card.skullIconLeft = skullIcon
    end

    return container
end

function CreateReviewCard(parent, index)
    local card = CreateFrame("Frame", nil, parent)
    card:SetHeight(REVIEW_HEIGHT)
    -- Position each card vertically, leaving 10px gap for each
    card:SetPoint("TOPLEFT", 0, -((index - 1) * (REVIEW_HEIGHT + 10)))
    card:SetPoint("RIGHT", -10, 0)

    card:SetBackdrop({
        bgFile = "Interface/AddOns/" .. addonName .. "/Media/Square_FullWhite.tga",
        edgeFile = "Interface/AddOns/" .. addonName .. "/Media/Square_FullWhite.tga",
        tile = true,
        tileEdge = true,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    card:SetBackdropColor(0.012, 0.02, 0.02, 1)
    card:SetBackdropBorderColor(0.298, 0.294, 0.298, 1)


    card.review = {}

    --------------------------------------------------------------------------------
    -- Create left and right review containers
    --------------------------------------------------------------------------------
    local sideWidth = card:GetWidth() / 2 - 5

    local leftReview = CreateFrame("Frame", nil, card)
    leftReview:SetWidth(sideWidth)
    leftReview:SetPoint("TOPLEFT", 8, -4)
    leftReview:SetPoint("BOTTOM", 0, 0)

    local rightReview = CreateFrame("Frame", nil, card)
    rightReview:SetWidth(sideWidth)
    rightReview:SetPoint("TOPLEFT", leftReview, "TOPRIGHT", 5, 0)
    rightReview:SetPoint("BOTTOMRIGHT", -5, 0)

    --------------------------------------------------------------------------------
    -- Create user panels (top section)
    --------------------------------------------------------------------------------
    local leftUserPanel, leftUserName = CreateUserPanel(leftReview, false)
    local rightUserPanel, rightUserName = CreateUserPanel(rightReview, true)
    card.userName = leftUserName
    card.userNameRight = rightUserName

    -- Only create timeAgo for left panel
    local timeAgo = leftUserPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeAgo:SetPoint("RIGHT", 25, 0)
    timeAgo:SetTextColor(0.5, 0.5, 0.5)
    card.timeAgo = timeAgo

    --------------------------------------------------------------------------------
    -- Create content panels (middle section)
    --------------------------------------------------------------------------------
    local itemPanel = CreateContentPanel(leftUserPanel, 36)
    local priceContainer = CreateContentPanel(rightUserPanel, 36)

    -- Set up item panel specifics
    local itemIcon = CreateFrame("Button", "ReviewLeftItem"..index, itemPanel, "ItemButtonTemplate")
    itemIcon:SetPoint("LEFT", 0, 0)
    card.itemIcon = itemIcon

    local itemNamePanel = CreateFrame("Frame", nil, itemPanel)
    itemNamePanel:SetHeight(36)
    itemNamePanel:SetPoint("LEFT", 40, 0)
    itemNamePanel:SetPoint("RIGHT", 0, 0)

    local itemName = itemNamePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("LEFT", 5, 0)
    itemName:SetPoint("RIGHT", -5, 0)
    itemName:SetJustifyH("LEFT")
    card.itemName = itemName

    -- Set up price widget
    local priceWidget = ns.CreatePriceWidget(priceContainer, {
        width = 135,
        height = 30,
    })
    card.priceWidget = priceWidget

    --------------------------------------------------------------------------------
    -- Create review panels (bottom section)
    --------------------------------------------------------------------------------
    local leftReviewPanel = CreateContentPanel(itemPanel, 60)
    local rightReviewPanel = CreateContentPanel(priceContainer, 60)

    local leftRatingPanel, leftStars = CreateRatingPanel(leftReviewPanel, false)
    local rightRatingPanel, rightStars = CreateRatingPanel(rightReviewPanel, true)
    card.starsLeft = leftStars
    card.starsRight = rightStars

    -- Create left side action container
    local actionContainerLeft = CreateActionContainer(leftReviewPanel, leftRatingPanel, card, false)
    -- Create right side action container
    local actionContainerRight = CreateActionContainer(rightReviewPanel, rightRatingPanel, card, true)

    -- item hover tooltip
    itemIcon:SetScript("OnEnter", function(self)
        if card.review.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(card.review.itemID)
            GameTooltip_ShowCompareItem()

            if IsModifiedClick("DRESSUP") then
                ShowInspectCursor()
            else
                ResetCursor()
            end
        end
    end)

    itemIcon:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        ResetCursor()
    end)

    itemIcon:SetScript("OnClick", function(self, button)
        if card.review.itemID then
            local _, link = ns.GetItemInfo(card.review.itemID)
            if link then
                HandleModifiedItemClick(link)
            end
        end
    end)

    return card
end


local function UpdateReviewSide(card, side, review)
    local isRight = side == "right"

    local me = UnitName("player")
    local isMeInvolved = me == review.rightReviewerName or me == review.leftReviewerName
    local bothHaveText = review.rightText and review.leftText

    local isMySide = false
    if isRight then
        isMySide = isMeInvolved and me == review.rightReviewerName
    else
        isMySide = isMeInvolved and me == review.leftReviewerName
    end

    local otherName = ""
    if isMeInvolved then
        if me == review.rightReviewerName then
            otherName = review.leftReviewerName
        else
            otherName = review.rightReviewerName
        end
    end

    -- Get the appropriate elements based on side
    local stars, button, timeRemaining, reviewText, text, rating, skullIcon, isSideDead, isOtherSideDead
    if isRight then
        stars = card.starsRight
        button = card.reviewButtonRight
        timeRemaining = card.timeRemainingTextRight
        reviewText = card.reviewTextRight
        text = review.rightText
        rating = review.rightRating
        skullIcon = card.skullIconRight
        isSideDead = review.rightReviewerDead
        isOtherSideDead = review.leftReviewerDead
    else
        stars = card.starsLeft
        button = card.reviewButtonLeft
        timeRemaining = card.timeRemainingTextLeft
        reviewText = card.reviewTextLeft
        text = review.leftText
        rating = review.leftRating
        skullIcon = card.skullIconLeft
        isSideDead = review.leftReviewerDead
        isOtherSideDead = review.rightReviewerDead
    end

    -- Calculate time remaining for review
    local timeLeft = ns.AuctionHouseAPI:GetTradeTimeLeft(review.trade)


    if (timeLeft > 0 and not bothHaveText) or not text then
        -- hide the real review text until timer runs out, or both parties submit their review
        local placeholder = L["Pending"]
        if text then
            placeholder = L["Completed Review"]
        elseif timeLeft <= 0 then
            placeholder = L["Didn't write a review"]
        end
        reviewText:SetText(placeholder)

        stars:Hide()
    else
        -- there is a review and we're allowed to show it
        reviewText:SetText(text or L["Pending Review"])

        stars:SetRating(rating or 0)
        stars:Show()
    end

    -- show time remaning if there is any
    if timeLeft > 0 and not text then
        timeRemaining:SetText(ns.GetTimeText(timeLeft))
        timeRemaining:SetTextColor(1, 0.82, 0) -- Golden yellow color
        timeRemaining:Show()
    else
        timeRemaining:Hide()
    end


    if isSideDead then
        skullIcon:Show()
    else
        skullIcon:Hide()
    end

    if isMeInvolved and not text and timeLeft > 0 and not isSideDead and not isOtherSideDead then
        button:SetText(isMySide and L["Write Review"] or WHISPER)
        button:SetScript("OnClick", function()
            if isMySide then
                ns.ShowReviewPopup(review.trade)
            else
                ChatFrame_OpenChat("/w " .. otherName .. " ")
            end
        end)
        button:Show()
    else
        button:Hide()
    end
end

local function UpdateReviewCardInner(card, review)
    card.review = review

    if review.itemID then
        -- Get item information based on itemID
        local itemName, _, quality, _, _, _, _, _, _, texture = ns.GetItemInfo(review.itemID, review.auction.quantity)
        local renderQuantity = review.auction.quantity
        if ns.IsFakeItem(review.itemID) then
            renderQuantity = 1
        end

        UpdateItemIcon(card.itemIcon:GetName(), texture, renderQuantity, true)

        -- Set the item name with color based on rarity
        local color = ITEM_QUALITY_COLORS[quality]
        card.itemName:SetText(itemName)
        if color then
            card.itemName:SetVertexColor(color.r, color.g, color.b)
        else
            card.itemName:SetVertexColor(1, 1, 1) -- Default to white if no color found
        end
    else
        -- display nothing (happen for athene feedback)
        UpdateItemIcon(card.itemIcon:GetName(), nil, 0, false)
        card.itemName:SetText("")
    end

    -- price (right side)
    card.priceWidget:UpdateView(review.auction)


    card.userName:SetText(review.leftReviewer or L["Unknown"])
    card.userNameRight:SetText(review.rightReviewer or L["Unknown"])

    -- Update both sides using the new function
    UpdateReviewSide(card, "left", review)
    UpdateReviewSide(card, "right", review)

    -- Update center elements
    card.timeAgo:SetText(review.timeAgo or "")

    card:Show()
end

local function UpdateReviewCard(card, review)
    if not review.itemID or review.itemID == 0 then
        UpdateReviewCardInner(card, review)
        return
    end

    -- item info might not be available yet, potentially wait for it to load
    ns.GetItemInfoAsync(review.itemID, function()
        UpdateReviewCardInner(card, review)
    end)
end

function OFReviewBrowse_Update()
    local reviews = GetReviews(OFAuctionFrameReviews.selectedTab)
    local numReviews = #reviews
    local page = OFAuctionFrameReviews.page or 1
    local startIndex = (page - 1) * OF_REVIEWS_PER_PAGE + 1

    -- Calculate how many items should be shown on this page
    local itemsRemaining = numReviews - startIndex + 1
    local numPageReviews = math.min(itemsRemaining, OF_REVIEWS_PER_PAGE)

    -- We have card frames pre-created in OFAuctionFrameReviews.reviewScrollContent.cards
    local cards = OFAuctionFrameReviews.reviewScrollContent.cards
    if not cards then
        return
    end

    for i = 1, OF_REVIEWS_PER_PAGE do
        local card = cards[i]
        local reviewIndex = startIndex + i - 1
        if reviewIndex <= numReviews then
            UpdateReviewCard(card, reviews[reviewIndex])
        else
            card:Hide()
        end
    end

    -- Update pagination buttons
    local prevButton = AHReviewPrevPageButton
    local nextButton = AHReviewNextPageButton

    if prevButton then
        -- Update button textures and states
        if page <= 1 then
            prevButton:Disable()
            prevButton:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
            prevButton:GetPushedTexture():SetVertexColor(0.5, 0.5, 0.5)
        else
            prevButton:Enable()
            prevButton:GetNormalTexture():SetVertexColor(1, 1, 1)
            prevButton:GetPushedTexture():SetVertexColor(1, 1, 1)
        end
    end

    if nextButton then
        if (page * OF_REVIEWS_PER_PAGE) >= numReviews then
            nextButton:Disable()
            nextButton:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
            nextButton:GetPushedTexture():SetVertexColor(0.5, 0.5, 0.5)
        else
            nextButton:Enable()
            nextButton:GetNormalTexture():SetVertexColor(1, 1, 1)
            nextButton:GetPushedTexture():SetVertexColor(1, 1, 1)
        end
    end

    -- See note in original code:
    FauxScrollFrame_Update(
        OFReviewScrollFrame,
        math.max(numPageReviews + 1, REVIEWS_IN_1_SCREEN + 1),
        REVIEWS_IN_1_SCREEN,
        REVIEW_HEIGHT + 10
    )
end

function OFAuctionFrameReviews_OnShow_Impl(self)
    -- default to Recent Reviews tab if no pending reviews
    local pendingReviews = ns.AuctionHouseAPI:GetPendingReviewCount()
    OFAuctionFrameReviews_SelectTab(pendingReviews > 0 and TAB_MY_REVIEWS or TAB_RECENT_REVIEWS)
    UpdateMyReviewsText()

    OFReviewBrowse_Update()
end

function AHReviewPrevPageButton_OnClick(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
    OFAuctionFrameReviews.page = (OFAuctionFrameReviews.page or 1) - 1;
    OFReviewScrollFrame:SetVerticalScroll(0);
    OFReviewBrowse_Update();
end

function AHReviewNextPageButton_OnClick(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
    OFAuctionFrameReviews.page = (OFAuctionFrameReviews.page or 1) + 1;
    OFReviewScrollFrame:SetVerticalScroll(0);
    OFReviewBrowse_Update();
end

function OFAuctionFrame_UpdateReviewsTabText()
    if not OFAuctionFrameTab4:IsShown() then
        return
    end

    local pendingReviews = ns.AuctionHouseAPI:GetPendingReviewCount()
    if pendingReviews > 0 then
        OFAuctionFrameTab4:SetText(string.format(L["Reviews (%d)"], pendingReviews))
    else
        OFAuctionFrameTab4:SetText(L["Reviews"])
    end
end

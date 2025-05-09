local addonName, ns = ...
local L = ns.L

OF_AH_ADDON_NAME = addonName

-- keep last item sent to auction & it's price

-- To experiment with different "20x" label strings, use:
-- /script AUCTION_PRICE_STACK_SIZE_LABEL = "%dx"

local FILTER_ALL_INDEX = -1;

OF_LAST_ITEM_AUCTIONED = "";
OF_LAST_ITEM_COUNT = 0;
OF_LAST_ITEM_BUYOUT = 0;

OF_NOTE_PLACEHOLDER = L["Leave a note..."]

OF_BROWSE_SEARCH_PLACEHOLDER = L["Search or wishlist"]

local TAB_BROWSE = 1
local TAB_AUCTIONS = 2
local TAB_PENDING = 3
local TAB_REVIEWS = 4
local TAB_LFG = 5
local TAB_DEATH_CLIPS = 6
local TAB_SETTINGS = 7
local TAB_ATHENE = 8
ns.AUCTION_TAB_BROWSE = TAB_BROWSE
ns.AUCTION_TAB_AUCTIONS = TAB_AUCTIONS
ns.AUCTION_TAB_PENDING = TAB_PENDING
ns.AUCTION_TAB_REVIEWS = TAB_REVIEWS
ns.AUCTION_TAB_LFG = TAB_LFG
ns.AUCTION_TAB_DEATH_CLIPS = TAB_DEATH_CLIPS
ns.AUCTION_TAB_SETTINGS = TAB_SETTINGS
ns.AUCTION_TAB_ATHENE = TAB_ATHENE

local BROWSE_PARAM_INDEX_PAGE = 7;
local PRICE_TYPE_UNIT = 1;
local PRICE_TYPE_STACK = 2;

local activeTooltipPriceTooltipFrame
local activeTooltipAuctionFrameItem
local allowLoans = false
local roleplay = false
local deathRoll = false
local duel = false
local currentSortParams = {}
local browseResultCache
local browseSortDirty = true
local auctionSellItemInfo

local selectedAuctionItems = {
    list = nil,
    bidder = nil,
    owner = nil,
}


local function pack(...)
    local table = {}
    for i = 1, select('#', ...) do
        table[i] = select(i, ...)
    end
    return table
end

local function OFGetAuctionSellItemInfo()
    if auctionSellItemInfo == nil then
        return nil
    end

    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = unpack(auctionSellItemInfo)

    -- Only fetch itemID from GetItemInfo if it's missing (ignore gold and enchants)
    if not itemID and name then
        local itemLink = select(2, GetItemInfo(name))
        itemID = itemLink and tonumber(string.match(itemLink, "item:(%d+)"))
    end

    return name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID
end

function OFGetCurrentSortParams(type)
    return currentSortParams[type].params
end

local function OFGetSelectedAuctionItem(type)
    return selectedAuctionItems[type]
end

local function OFSetSelectedAuctionItem(type, auction)
    selectedAuctionItems[type] = auction
end


function OFAllowLoansCheckButton_OnClick(button)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    allowLoans = not allowLoans
    if allowLoans then
        roleplay = false
        duel = false
        deathRoll = false

        -- only gold
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType ~= ns.PRICE_TYPE_MONEY then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            ToggleDropDownMenu(1, nil, OFPriceTypeDropdown, "cursor", 0, 0)
        end
    end
    OFUpdateAuctionSellItem()
end

function OFRoleplayCheckButton_OnClick(button)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    roleplay = not roleplay
    if roleplay then
        duel = false
        deathRoll = false
        allowLoans = false
    end
    OFUpdateAuctionSellItem()
end

function OFDeathRollCheckButton_OnClick(button)
    deathRoll = not deathRoll
    if deathRoll then
        duel = false
        roleplay = false
        allowLoans = false

        -- only gold allowed
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType ~= ns.PRICE_TYPE_MONEY then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            ToggleDropDownMenu(1, nil, OFPriceTypeDropdown, "cursor", 0, 0)
        end
    end
    OFSpecialFlagCheckButton_OnClick()
    OFUpdateAuctionSellItem()
end

function OFDuelCheckButton_OnClick(button)
    duel = not duel
    if duel then
        deathRoll = false
        roleplay = false
        allowLoans = false

        -- only gold allowed
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType ~= ns.PRICE_TYPE_MONEY then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            ToggleDropDownMenu(1, nil, OFPriceTypeDropdown, "cursor", 0, 0)
        end
    end
    OFSpecialFlagCheckButton_OnClick()
    OFUpdateAuctionSellItem()
end

function OFSpecialFlagCheckButton_OnClick()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if deathRoll or duel then
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType == ns.PRICE_TYPE_TWITCH_RAID then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            ToggleDropDownMenu(1, nil, OFPriceTypeDropdown, "cursor", 0, 0)
        end
        local deliveryType = OFAuctionFrameAuctions.deliveryTypeIndex
        if deliveryType ~= ns.DELIVERY_TYPE_TRADE then
            OFSetupDeliveryDropdown(OFAuctionFrameAuctions, ns.DELIVERY_TYPE_TRADE)
            ToggleDropDownMenu(1, nil, OFDeliveryDropdown, "cursor", 0, 0)
        end
    end
end

local function GetAuctionSortColumn(sortTable)
	local existingSortColumn, existingSortReverse = currentSortParams[sortTable].column, currentSortParams[sortTable].desc

	-- The "bid" column can now be configured to sort by per-unit bid price ("unitbid"),
	-- per-unit buyout price ("unitprice"), or total buyout price ("totalbuyout") instead of
	-- always sorting by total bid price ("bid"). Map these new sort options to the "bid" column.
	if (existingSortColumn == "totalbuyout" or existingSortColumn == "unitbid" or existingSortColumn == "unitprice") then
		existingSortColumn = "bid";
	end

	return existingSortColumn, existingSortReverse
end


local function GetBuyoutPrice()
	local buyoutPrice = MoneyInputFrame_GetCopper(OFBuyoutPrice);
	return buyoutPrice;
end


function OFBrowseFulfillButton_OnClick(button)
    ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, false,
            function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
            function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
            function() button:Enable() end
    )
end

function OFBrowseLoanButton_OnClick(button)
    ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, true,
        function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
        function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
        function() button:Enable() end
    )
end

function OFBrowseBuyoutButton_OnClick(button)
    if OFAuctionFrame.auction.deathRoll then
        StaticPopup_Show("OF_BUY_AUCTION_DEATH_ROLL")
    elseif OFAuctionFrame.auction.duel then
        StaticPopup_Show("OF_BUY_AUCTION_DUEL")
    elseif OFAuctionFrame.auction.itemID == ns.ITEM_ID_GOLD then
        StaticPopup_Show("OF_BUY_AUCTION_GOLD")
    else
        ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, false,
            function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
            function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
            function() button:Enable() end
        )
    end
end

function OFBidWhisperButton_OnClick()
    local auction = OFAuctionFrame.auction
    local name = UnitName("player") == auction.owner and auction.buyer or auction.owner
    ChatFrame_SendTell(name)
end

function OFBidInviteButton_OnClick()
    local auction = OFAuctionFrame.auction
    local name = UnitName("player") == auction.owner and auction.buyer or auction.owner
    InviteUnit(name)
end

StaticPopupDialogs["OF_CANCEL_AUCTION_PENDING"] = {
    text = L["Are you sure you want to cancel this auction?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:CancelAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnCancel = function(self)
        OFBidCancelAuctionButton:Enable()
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_CANCEL_AUCTION_ACTIVE"] = {
    text = L["Are you sure you want to cancel this auction?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:CancelAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameAuctions_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnCancel = function(self)
        OFAuctionsCancelAuctionButton:Enable();
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

local function CreateSpecialModifierBuyConfirmPrompt(text)
    return {
        text = text,
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            local _, err = ns.AuctionHouseAPI:RequestBuyAuction(OFAuctionFrame.auction.id, 0)
            if err == nil then
                OFAuctionFrameBrowse_Update()
            else
                UIErrorsFrame:AddMessage(err, 1.0, 0.1, 0.1, 1.0)
            end
        end,
        OnShow = function(self)
            MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
        end,
        OnCancel = function(self)
            OFBrowseBuyoutButton:Enable()
        end,
        hasMoneyFrame = 1,
        showAlert = 1,
        timeout = 0,
        exclusive = 1,
        hideOnEscape = 1
    }
end

StaticPopupDialogs["OF_BUY_AUCTION_DEATH_ROLL"] = CreateSpecialModifierBuyConfirmPrompt(L["Are you sure you want to accept a death roll for this auction?"])

StaticPopupDialogs["OF_BUY_AUCTION_DUEL"] = CreateSpecialModifierBuyConfirmPrompt(L["Are you sure you want to accept a duel for this auction?"])

StaticPopupDialogs["OF_BUY_AUCTION_GOLD"] = {
    text = L["Are you sure you want to buy this auction?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local _, err = ns.AuctionHouseAPI:RequestBuyAuction(OFAuctionFrame.auction.id, 0)
        if err == nil then
            OFAuctionFrameBrowse_Update()
        else
            UIErrorsFrame:AddMessage(err, 1.0, 0.1, 0.1, 1.0)
        end
    end,
    OnCancel = function(self)
        OFBrowseBuyoutButton:Enable()
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

StaticPopupDialogs["OF_DECLINE_ALL"] = {
	text = L["Are you sure you want to unlist all your pending orders?"],
    button1 = YES,
    button2 = NO,
	OnAccept = function()
		-- Cancel each auction
        local allAuctions = ns.AuctionHouseAPI:GetMySellPendingAuctions()
		for _, auction in pairs(allAuctions) do
			ns.AuctionHouseAPI:CancelAuction(auction.id)
		end
	end,
    showAlert = 1,
	timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["OF_FORGIVE_LOAN"] = {
    text = L["Mark loan complete? This will complete the trade."],
    button1 = L["Mark Loan Complete"],
    button2 = CANCEL,
    OnAccept = function(self)
        local error = ns.AuctionHouseAPI:MarkLoanComplete(OFAuctionFrame.auction.id)
        if error == nil then
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price);
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable();
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_DECLARE_BANKRUPTCY"] = {
    text = L["Declare Bankruptcy? This will complete the trade without fulfilling your end of the deal."],
    button1 = L["Declare Bankruptcy"],
    button2 = CANCEL,
    OnAccept = function(self)
        local error = ns.AuctionHouseAPI:DeclareBankruptcy(OFAuctionFrame.auction.id)
        if error == nil then
            PlaySoundFile("Interface\\AddOns\\"..addonName.."\\Media\\bankruptcy.mp3", "Master")
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable()
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_MARK_AUCTION_COMPLETE"] = {
    text = L["Mark auction complete? This will complete the trade."],
    button1 = L["Mark Auction Complete"],
    button2 = CANCEL,
    OnAccept = function(self)
        local auction, trade, error = ns.AuctionHouseAPI:CompleteAuction(OFAuctionFrame.auction.id)
        if error == nil then
            OFAuctionFrameBid_Update()
            if auction then
                StaticPopup_Show("OF_LEAVE_REVIEW", nil, nil, { tradeID = trade.id });
            end
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        if OFAuctionFrame.auction.priceType == ns.PRICE_TYPE_MONEY then
            MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
        else
            self.moneyFrame:Hide()
        end
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable()
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_FULFILL_AUCTION"] = {
    text = L["Are you sure you want to fulfill this wishlist request?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:RequestFulfillAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameSwitchTab(TAB_PENDING)
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        local auction = OFAuctionFrame.auction
        if auction.priceType == ns.PRICE_TYPE_MONEY then
            MoneyFrame_Update(self.moneyFrame, auction.price)
        else
            self.moneyFrame:Hide()
        end
        ns.GetItemInfoAsync(auction.itemID, function(...)
            local item = ns.ItemInfoToTable(...)
            local itemName
            if auction.itemID == ns.ITEM_ID_GOLD then
                itemName = ns.GetMoneyString(auction.quantity)
            else
                itemName = item.name
                if auction.quantity > 1 then
                    itemName = itemName .. " x" .. auction.quantity
                end
            end
            local name = ns.GetDisplayName(auction.owner)
            self.text:SetText(string.format(L["Are you sure you want to fulfill the wishlist request of %s for %s?"], name, itemName))
        end)
    end,
    OnCancel = function(self)
        OFBrowseFulfillButton:Enable();
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

function OFUpdateAuctionSellItem()
    OFRoleplayCheckButton:SetChecked(roleplay)
    OFAllowLoansCheckButton:SetChecked(allowLoans)
    OFDeathRollCheckButton:SetChecked(deathRoll)
    OFDuelCheckButton:SetChecked(duel)


    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    if priceType == ns.PRICE_TYPE_MONEY then
        OFBuyoutPrice:Show()
        OFTwitchRaidViewerAmount:Hide()
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        OFBuyoutPrice:Hide()
        OFTwitchRaidViewerAmount:Show()
        OFTwitchRaidViewerAmountText:SetText(L_MIN_TWITCH_VIEWERS)
    elseif priceType == ns.PRICE_TYPE_GUILD_POINTS then
        OFBuyoutPrice:Hide()
        OFTwitchRaidViewerAmount:Show()
        OFTwitchRaidViewerAmountText:SetText(L["Amount"])
    else
        OFBuyoutPrice:Hide()
        OFTwitchRaidViewerAmount:Hide()
    end
    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
    local isGold = itemID == ns.ITEM_ID_GOLD
    if isGold then
        OFBuyoutPrice:Hide()
    end

    if (texture) then
        OFAuctionsItemButton:SetNormalTexture(texture)
    else
        OFAuctionsItemButton:SetNormalTexture(nil)
    end

    OFAuctionsItemButton.stackCount = stackCount
    OFAuctionsItemButton.totalCount = totalCount
    OFAuctionsItemButton.pricePerUnit = pricePerUnit
    OFAuctionsItemButtonName:SetText(name or "")
    OFAuctionsItemButtonCount:SetText(count or "")
    if ((count == nil or count > 1) and not isGold) then
        OFAuctionsItemButtonCount:Show()
    else
        OFAuctionsItemButtonCount:Hide()
    end
    OFAuctionsFrameAuctions_ValidateAuction()
end

local function LockCheckButton(button, value)
    button:Disable()
    button:SetChecked(value)
    _G[button:GetName().."Text"]:SetTextColor(0.5, 0.5, 0.5)
end

local function UnlockCheckButton(button)
    button:Enable()
    _G[button:GetName().."Text"]:SetTextColor(1, 1, 1)
end

local function OnMoneySelected(self)
    if not self.moneyInputFrame then
        return
    end

    local copper = MoneyInputFrame_GetCopper(self.moneyInputFrame)
    local myMoney = GetMoney()
    if myMoney < copper then
        PlaySound(847) -- Plays the default "error" sound
        UIErrorsFrame:AddMessage(ERR_NOT_ENOUGH_MONEY, 1.0, 0.1, 0.1, 1.0)
        return
    end
    local name, _, quality, _, _, _, _, stackCount, _, texture = ns.GetGoldItemInfo(copper)
    name = ITEM_QUALITY_COLORS[quality].hex..name.."|r"
    -- name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID
    auctionSellItemInfo = pack(name, texture, copper, quality, true, copper, 1, stackCount, myMoney, ns.ITEM_ID_GOLD)
    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    allowLoans = false
    LockCheckButton(OFAllowLoansCheckButton, false)
    OFUpdateAuctionSellItem()
end

function OFSelectEnchantForAuction(itemID)
    local name, _, quality, _, _, _, _, stackCount, _, texture = ns.GetSpellItemInfo(itemID)
    name = ITEM_QUALITY_COLORS[quality].hex..name.."|r"
    auctionSellItemInfo = pack(name, texture, 1, quality, true, 1, 1, stackCount, 1, itemID)
    UnlockCheckButton(OFAllowLoansCheckButton)
    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    OFUpdateAuctionSellItem()
end

StaticPopupDialogs["OF_SELECT_AUCTION_MONEY"] = {
    text = L["Select the amount for the auction"],
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self)
        OnMoneySelected(self)
    end,
    OnHide = function(self)
        MoneyInputFrame_ResetMoney(self.moneyInputFrame)
    end,
    EditBoxOnEnterPressed = function(self)
        OnMoneySelected(self)
    end,
    hasMoneyInputFrame = 1,
    timeout = 0,
    hideOnEscape = 1
};

--local original = ContainerFrameItemButton_OnClick
--function ContainerFrameItemButton_OnClick(self, button, ...)
--    if button == "RightButton" and OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
--        local bagIdx, slotIdx = self:GetParent():GetID(), self:GetID()
--        C_Container.PickupContainerItem(bagIdx, slotIdx);
--        OFAuctionSellItemButton_OnClick(AuctionsItemButton, "LeftButton")
--    else
--        return original(self, button, ...)
--    end
--end


function OFAuctionFrame_OnLoad (self)
    if not OFAuctionFrameBrowse.OFFilterButtons then
        OFAuctionFrameBrowse.OFFilterButtons = {}
        for _, child in ipairs({ OFAuctionFrameBrowse:GetChildren() }) do
            if child:IsObjectType("Button") and string.find(child:GetName(), "OFAuctionFilterButton") then
                table.insert(OFAuctionFrameBrowse.OFFilterButtons, child)
            end
        end
    end
    
    tinsert(UISpecialFrames, "OFAuctionFrame")

	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, 8);
	PanelTemplates_SetTab(self, 1);

	-- Set focus rules
	OFBrowseFilterScrollFrame.ScrollBar.scrollStep = OF_BROWSE_FILTER_HEIGHT;

	-- Init search dot count
	OFAuctionFrameBrowse.dotCount = 0;
	OFAuctionFrameBrowse.isSearchingThrottle = 0;

	OFAuctionFrameBrowse.page = 0;
	FauxScrollFrame_SetOffset(OFBrowseScrollFrame,0);

	OFAuctionFrameBid.page = 0;
	FauxScrollFrame_SetOffset(OFBidScrollFrame,0);
	GetBidderAuctionItems(OFAuctionFrameBid.page);

	OFAuctionFrameAuctions.page = 0;
	FauxScrollFrame_SetOffset(OFAuctionsScrollFrame,0);

	MoneyFrame_SetMaxDisplayWidth(OFAuctionFrameMoneyFrame, 160);

	--if GetClassicExpansionLevel() == LE_EXPANSION_CLASSIC then
		--Vanilla textures are slightly different from later expansions so we need to adjust the placement of the BrowseResetButton
	--	OFBrowseResetButton:SetSize(97, 22);
	--	OFBrowseResetButton:SetPoint("TOPLEFT", 37, -79);
	--end
end

function OFAuctionFrame_Show()
	if ( OFAuctionFrame:IsShown() ) then
		OFAuctionFrameBrowse_Update();
		OFAuctionFrameBid_Update();
		OFAuctionFrameAuctions_Update();
	else
		ShowUIPanel(OFAuctionFrame);

		OFAuctionFrameBrowse.page = 0;
		FauxScrollFrame_SetOffset(OFBrowseScrollFrame,0);

		OFAuctionFrameBid.page = 0;
		FauxScrollFrame_SetOffset(OFBidScrollFrame,0);
		GetBidderAuctionItems(OFAuctionFrameBid.page);

		OFAuctionFrameAuctions.page = 0;
		FauxScrollFrame_SetOffset(OFAuctionsScrollFrame,0);

		OFBrowsePrevPageButton.isEnabled = false;
		OFBrowseNextPageButton.isEnabled = false;
		OFBrowsePrevPageButton:Disable();
		OFBrowseNextPageButton:Disable();
		
		if ( not OFAuctionFrame:IsShown() ) then
			CloseAuctionHouse();
		end
	end
end

function OFAuctionFrame_Hide()
	HideUIPanel(OFAuctionFrame);
end

local initialTab = TAB_BROWSE
function OFAuctionFrame_OverrideInitialTab(tab)
    initialTab = tab
end

function AuctionFrame_UpdatePortrait()
    -- if ns.IsAtheneBlocked() then
    --     SetPortraitTexture(OFAuctionPortraitTexture, "player");
    -- else
    SetPortraitTexture(OFAuctionPortraitTexture, "player")
    -- end
end


function OFAuctionFrame_SetUpSideDressUpFrame(parentFrame, anchorPoint, relativeTo, offsetX, offsetY)
    local dressUpFrame = _G["DressUpFrame"]
    dressUpFrame:SetParent(parentFrame)
    dressUpFrame:SetPoint(anchorPoint, parentFrame, relativeTo, offsetX, offsetY)
    dressUpFrame:SetMovable(true)
    dressUpFrame:SetUserPlaced(true)
    dressUpFrame:SetClampedToScreen(true)
    dressUpFrame:Show()
    dressUpFrame.ResetButton:Click()
end

function OFAuctionFrame_OnShow (self)
    OFAuctionFrameSwitchTab(initialTab)
    initialTab = TAB_BROWSE

    AuctionFrame_UpdatePortrait()
	OFBrowseNoResultsText:SetText(BROWSE_SEARCH_TEXT);
	PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN);

	--OFAuctionFrame_SetUpSideDressUpFrame(self, "TOPLEFT", "TOPRIGHT", -2, -14);
    OFAuctionFrame_UpdateReviewsTabText()
    OFAuctionFrame_UpdateAtheneTab()
end

function OFAuctionFrameTab_OnClick(self, button, down)
    local index = self:GetID();
    OFAuctionFrameSwitchTab(index)
end

function OFAuctionFrameReviews_OnLoad(self)
    OFAuctionFrameReviews_OnLoad_Impl(self)
end

function OFAuctionFrameReviews_Update(self)
    OFAuctionFrameReviews_OnShow_Impl(self)
end

local function AssignReviewTextures(includingLeftBorder)
    local basepath = "Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-review-"

    if includingLeftBorder then
        OFAuctionFrameBotLeft:SetTexture(basepath .. "botleft")
        OFAuctionFrameTopLeft:SetTexture(basepath .. "topleft")
    else
        local basepath2 = "Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-clip-"
        OFAuctionFrameBotLeft:SetTexture(basepath2 .. "botleft")
        OFAuctionFrameTopLeft:SetTexture(basepath2 .. "topleft")
    end
    OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Top")
    OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Top")
    OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopRight")
    OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Bot")
    OFAuctionFrameBotRight:SetTexture(basepath .. "botright")
end

local function AssignCreateOrderTextures()
    local basepath = "Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-auction-"

    OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft");
    OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
    OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
    --TODO FIXME 3.3.5 cannot use the blp file from the folder, using blizzard one for now
    --OFAuctionFrameBotLeft:SetTexture(basepath .. "botleft.blp");
    OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotLeft");
    OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
    OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotRight");
end

local function AssignLFGTextures()
    AssignCreateOrderTextures()

    --OFAuctionFrameTopLeft:SetTexture("Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-stream-together-topleft.blp")
    OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft")
    OFAuctionFrameBotRight:SetTexture("Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-review-botright.blp")
end

function OFAuctionFrameSwitchTab(index)
	PanelTemplates_SetTab(OFAuctionFrame, index)
	OFAuctionFrameAuctions:Hide()
	OFAuctionFrameBrowse:Hide()
	OFAuctionFrameBid:Hide()
    OFAuctionFrameReviews:Hide()
    OFAuctionFrameDeathClips:Hide()
    OFAuctionFrameSettings:Hide()
    OFAuctionFrameLFG:Hide()
    OFAuctionFrameAthene:Hide()
    OFAuctionFrameSettings_OnSwitchTab()
    SetAuctionsTabShowing(false)

	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)

	if ( index == TAB_BROWSE ) then
		OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopLeft");
		OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Top");
		OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopRight");
		OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotLeft");
		OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
		OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
		OFAuctionFrameBrowse:Show();
		OFAuctionFrame.type = "list";
	elseif ( index == TAB_AUCTIONS ) then
		-- OFAuctions tab
        AssignCreateOrderTextures()
		OFAuctionFrameAuctions:Show();
		SetAuctionsTabShowing(true);
    elseif ( index == TAB_PENDING ) then
        OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft");
        OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
        OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
        OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft");
        OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
        OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
        OFAuctionFrameBid:Show();
        OFAuctionFrame.type = "bidder";
    elseif ( index == TAB_REVIEWS ) then
        AssignReviewTextures(true)

        OFAuctionFrameReviews:Show()
        OFAuctionFrame.type = "reviews";
    elseif ( index == TAB_LFG ) then
        AssignLFGTextures()
        OFAuctionFrameLFG:Show()
        OFAuctionFrame.type = "lfg";
    elseif ( index == TAB_DEATH_CLIPS ) then
        AssignReviewTextures()
        OFAuctionFrameDeathClips:Show()
        OFAuctionFrame.type = "clips"
    elseif ( index == TAB_SETTINGS ) then
        AssignReviewTextures(true)
        OFAuctionFrameSettings:Show()
        OFAuctionFrame.type = "settings"
    elseif ( index == TAB_ATHENE ) then
        AssignLFGTextures()
        OFAuctionFrameAthene:Show()
        OFAuctionFrame.type = "athene"
    end

    local icnOffset
    if index == TAB_ATHENE then
        icnOffset = 6
    else
        icnOffset = 3
    end
end

-- Browse tab functions

function OFAuctionFrameBrowse_OnLoad(self)
    -- set default sort
    OFAuctionFrame_SetSort("list", "quality", true)

    local markDirty = function()
        browseResultCache = nil
    end
    local function markDirtyAndUpdate()
        markDirty()
        if OFAuctionFrame:IsShown() and OFAuctionFrameBrowse:IsShown() then
            OFAuctionFrameBrowse_Update()
        end
    end
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, function()
        markDirtyAndUpdate()
    end)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, markDirty)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, markDirty)

    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, markDirtyAndUpdate)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_DELETED, markDirtyAndUpdate)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_BLACKLIST_STATE_UPDATE, markDirtyAndUpdate)

	self.qualityIndex = FILTER_ALL_INDEX;
end



function OFAuctionFrameBrowse_UpdateArrows()
	OFSortButton_UpdateArrow(OFBrowseQualitySort, "list", "quality")
	OFSortButton_UpdateArrow(OFBrowseTypeSort, "list", "type")
    OFSortButton_UpdateArrow(OFBrowseLevelSort, "list", "level")
    OFSortButton_UpdateArrow(OFBrowseDeliverySort, "list", "delivery")
	OFSortButton_UpdateArrow(OFBrowseHighBidderSort, "list", "seller")
    OFSortButton_UpdateArrow(OFBrowseRatingSort, "list", "rating")
	OFSortButton_UpdateArrow(OFBrowseCurrentBidSort, "list", "bid")
end


function OFRequestItemButton_OnClick(button)
    --print("Request item", button:GetParent().itemID, button:GetParent().item.equipSlot)
    ns.AuctionWishlistConfirmPrompt:Show(
        button:GetParent().itemID,
        nil,
        function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
        nil
    )
end

function OFSelectSpecialItemButton_OnClick(button)
    if button:GetParent().isEnchantEntry then
        ns.ShowAuctionSelectEnchantPrompt()
    else
        StaticPopup_Show("OF_SELECT_AUCTION_MONEY")
    end
end

function OFBrowseButton_OnClick(button)
	assert(button);
	
	OFSetSelectedAuctionItem("list", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameBrowse_Update()
end

function OFAuctionFrameBrowse_Reset(self)
	OFBrowseName:SetText(OF_BROWSE_SEARCH_PLACEHOLDER)
	OFBrowseMinLevel:SetText("")
	OFBrowseMaxLevel:SetText("")
    OFOnlineOnlyCheckButton:SetChecked(false)
    OFAuctionsOnlyCheckButton:SetChecked(false)

	-- reset the filters
	OF_OPEN_FILTER_LIST = {}
	OFAuctionFrameBrowse.selectedCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil

	OFAuctionFrameFilters_Update()
    OFAuctionFrameBrowse_Search()
    OFAuctionFrameBrowse_Update()
	self:Disable()
end

function OFBrowseResetButton_OnUpdate(self, elapsed)
    local search = OFBrowseName:GetText()
	if ( (search == "" or search == OF_BROWSE_SEARCH_PLACEHOLDER) and (OFBrowseMinLevel:GetText() == "") and (OFBrowseMaxLevel:GetText() == "") and
         (not OFOnlineOnlyCheckButton:GetChecked()) and
	     (not OFAuctionFrameBrowse.selectedCategoryIndex))
	then
		self:Disable()
	else
		self:Enable()
	end
end

function OFAuctionFrame_SetSort(sortTable, sortColumn, oppositeOrder)
    local template = OFAuctionSort[sortTable.."_"..sortColumn]
    local sortParams = {}
	-- set the columns
	for index, row in pairs(template) do
		-- Browsing by the "bid" column will sort by whatever price sorrting option the user selected
		-- instead of always sorting by "bid" (total bid price)
		local sort = row.column;
        local reverse
		if (oppositeOrder) then
            reverse = not row.reverse
		else
            reverse = row.reverse
		end
        table.insert(sortParams, { column = sort, reverse = reverse })
	end
    currentSortParams[sortTable] = {
        column = sortColumn,
        desc = oppositeOrder,
        params = sortParams,
    }
    if sortTable == "list" then
        browseSortDirty = true
    end
end

function OFAuctionFrame_OnClickSortColumn(sortTable, sortColumn)
	-- change the sort as appropriate
	local existingSortColumn, existingSortReverse = GetAuctionSortColumn(sortTable)
	local oppositeOrder = false
	if (existingSortColumn and (existingSortColumn == sortColumn)) then
		oppositeOrder = not existingSortReverse
	elseif (sortColumn == "level") then
		oppositeOrder = true
	end

	-- set the new sort order
	OFAuctionFrame_SetSort(sortTable, sortColumn, oppositeOrder)

	-- apply the sort
    if (sortTable == "list") then
        OFAuctionFrameBrowse_Search()
    elseif(sortTable == "bidder") then
        OFAuctionFrameBid_Update()
    elseif (sortTable == "owner") then
        OFAuctionFrameAuctions_Update()
    elseif (sortTable == "clips") then
        OFAuctionFrameDeathClips_Update()
    elseif (sortTable == "lfg") then
        OFLFGScroll_Update()
    end
end

---@type BrowseParams
local prevBrowseParams

---@param newParams BrowseParams
local function OFAuctionFrameBrowse_SearchHelper(newParams)
    local page = newParams.page

	if prevBrowseParams then
		-- if we have already done a browse then see if any of the params have changed (except for the page number)
        for k, v in pairs(newParams) do
            if ( k ~= "page" and v ~= prevBrowseParams[k] ) then
                -- if we detect a change then we want to reset the page number back to the first page
                page = 0;
                OFAuctionFrameBrowse.page = page;
                break;
            end
        end
	end

    newParams.page = page
    prevBrowseParams = newParams
end

function OFAuctionsOnlyCheckButton_OnClick(self)
    ns.PlayerPrefs:Set("OFAuctionsOnlyCheckButton", self:GetChecked())
    OFAuctionFrameBrowse_Search()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function OFOnlineOnlyCheckButton_OnClick(self)
    ns.PlayerPrefs:Set("OFOnlineOnlyCheckButton", self:GetChecked())
    OFAuctionFrameBrowse_Search()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function OFAuctionFrameBrowse_OnShow()
    OFAuctionFrameBrowse_Reset(OFBrowseResetButton)

    OFOnlineOnlyCheckButton:SetChecked(ns.PlayerPrefs:Get("OFOnlineOnlyCheckButton") or false)
    OFAuctionsOnlyCheckButton:SetChecked(ns.PlayerPrefs:Get("OFAuctionsOnlyCheckButton") or false)

    local auctions = ns.GetBrowseAuctions({}, {})
    local itemIds = {}
    for _, auction in ipairs(auctions) do
        itemIds[auction.itemID] = ns.GetItemInfo(auction.itemID) ~= nil
    end

    local frame = CreateFrame("FRAME")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", function(self, event, ...)
        local itemId, success = ...
        if itemIds[itemId] ~= nil then
            itemIds[itemId] = true
        end
        local allDone = true
        for _, done in pairs(itemIds) do
            if not done then
                allDone = false
                break
            end
        end
        if allDone then
            OFAuctionFrameBrowse_Update()
            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end)

    for itemId, hasInfo in pairs(itemIds) do
        if not hasInfo then
            C_Item.RequestLoadItemDataByID(itemId)
        end
    end
end
-- If string is quoted, return the string with the quotes removed, otherwise return nil.
local function DequoteString(s)
	-- Recognize the ASCII double character quote or (unlike mainline) Unicode curly double quotes.
	-- Also recognize the French "guillemet" double angle quote characters since the mainline
	-- auction house converts those to ASCII double quotes in CaseAccentInsensitiveParseInternal().
	-- Always recognize any of these quote characters, regardless of the user's locale setting.

	-- Unicode code points as UTF-8 strings.
	local doubleQuote = '"';					-- U+0022 Quotation Mark
	local leftDoubleQuote = "\226\128\156";		-- U+201C Left Double Quotation Mark
	local rightDoubleQuote = "\226\128\157";	-- U+201D Right Double Quotation Mark
	local leftGuillemet = "\194\171";			-- U+00AB Left-Pointing Double Angle Quotation Mark
	local rightGuillemet = "\194\187";			-- U+00BB Right-Pointing Double Angle Quotation Mark

	-- Check is the search string starts with a recognized opening quote and get its UTF-8 length.
	local quoteLen = 0;

	if (#s >= #doubleQuote and string.sub(s, 1, #doubleQuote) == doubleQuote) then
		quoteLen = #doubleQuote;
	elseif (#s >= #leftDoubleQuote and string.sub(s, 1, #leftDoubleQuote) == leftDoubleQuote) then
		quoteLen = #leftDoubleQuote;
	elseif (#s >= #leftGuillemet and string.sub(s, 1, #leftGuillemet) == leftGuillemet) then
		quoteLen = #leftGuillemet;
	end

	if (quoteLen == 0) then
		return nil;
	end

	-- Trim the opening quote
	s = string.sub(s, quoteLen + 1);

	-- Check is the search string ends with a recognized closing quote and get its UTF-8 length.
	quoteLen = 0;

	if (#s >= #doubleQuote and string.sub(s, -#doubleQuote) == doubleQuote) then
		quoteLen = #doubleQuote;
	elseif (#s >= #rightDoubleQuote and string.sub(s, -#rightDoubleQuote) == rightDoubleQuote) then
		quoteLen = #rightDoubleQuote;
	elseif (#s >= #rightGuillemet and string.sub(s, -#rightGuillemet) == rightGuillemet) then
		quoteLen = #rightGuillemet;
	end

	if (quoteLen == 0) then
		return nil;
	end

	-- Trim the closing quote	
	return string.sub(s, 1, -(quoteLen + 1));
end

function OFAuctionFrameBrowse_Search()
    if ( not OFAuctionFrameBrowse.page ) then
        OFAuctionFrameBrowse.page = 0;
    end

    -- If the search string is in quotes, do an exact match on the dequoted string, otherwise
    -- do the default substring search.
    local exactMatch = false;
    local text = OFBrowseName:GetText();
    if text == OF_BROWSE_SEARCH_PLACEHOLDER then
        OFBrowseName:SetTextColor(0.7, 0.7, 0.7);
        text = ""
    else
        OFBrowseName:SetTextColor(1, 1, 1);
    end
    local dequotedText = DequoteString(text);
    if ( dequotedText ~= nil ) then
        exactMatch = true;
        text = dequotedText;
    end
    local minLevel, maxLevel
    if OFBrowseMinLevel:GetText() ~= "" then
        minLevel = tonumber(OFBrowseMinLevel:GetNumber())
    end
    if OFBrowseMaxLevel:GetText() ~= "" then
        maxLevel = tonumber(OFBrowseMaxLevel:GetNumber())
    end

    OFAuctionFrameBrowse_SearchHelper(BrowseParams.New(
        text,
        minLevel,
        maxLevel,
        OFAuctionFrameBrowse.selectedCategoryIndex,
        OFAuctionFrameBrowse.selectedSubCategoryIndex,
        OFAuctionFrameBrowse.selectedSubSubCategoryIndex,
        OFAuctionFrameBrowse.page,
        OFAuctionFrameBrowse.factionIndex,
        exactMatch,
        OFOnlineOnlyCheckButton:GetChecked(),
        OFAuctionsOnlyCheckButton:GetChecked()
    ))
    -- after updating filters, we need to query auctions and item db again
    browseResultCache = nil

    OFAuctionFrameBrowse_Update()
    OFBrowseNoResultsText:SetText(BROWSE_NO_RESULTS);
end

function OFBrowseSearchButton_OnUpdate(self, elapsed)
    self:Enable();
    if ( OFBrowsePrevPageButton.isEnabled ) then
        OFBrowsePrevPageButton:Enable()
    else
        OFBrowsePrevPageButton:Disable()
    end
    if ( OFBrowseNextPageButton.isEnabled ) then
        OFBrowseNextPageButton:Enable()
    else
        OFBrowseNextPageButton:Disable()
    end
    OFAuctionFrameBrowse_UpdateArrows()

	if (OFAuctionFrameBrowse.isSearching) then
		if ( OFAuctionFrameBrowse.isSearchingThrottle <= 0 ) then
			OFAuctionFrameBrowse.dotCount = OFAuctionFrameBrowse.dotCount + 1;
			if ( OFAuctionFrameBrowse.dotCount > 3 ) then
				OFAuctionFrameBrowse.dotCount = 0
			end
			local dotString = "";
			for i=1, OFAuctionFrameBrowse.dotCount do
				dotString = dotString..".";
			end
			OFBrowseSearchDotsText:Show();
			OFBrowseSearchDotsText:SetText(dotString);
			OFBrowseNoResultsText:SetText(SEARCHING_FOR_ITEMS);
			OFAuctionFrameBrowse.isSearchingThrottle = 0.3;
		else
			OFAuctionFrameBrowse.isSearchingThrottle = OFAuctionFrameBrowse.isSearchingThrottle - elapsed;
		end
	else
		OFBrowseSearchDotsText:Hide();
	end
end

function OFAuctionFrameFilters_Update(forceSelectionIntoView)
	OFAuctionFrameFilters_UpdateCategories(forceSelectionIntoView);
	-- Update scrollFrame
	FauxScrollFrame_Update(OFBrowseFilterScrollFrame, #OF_OPEN_FILTER_LIST, OF_NUM_FILTERS_TO_DISPLAY, OF_BROWSE_FILTER_HEIGHT);
end

function OFAuctionFrameFilters_UpdateCategories(forceSelectionIntoView)
	-- Initialize the list of open filters
	OF_OPEN_FILTER_LIST = {};

	for categoryIndex, categoryInfo in ipairs(OFAuctionCategories) do
		local selected = OFAuctionFrameBrowse.selectedCategoryIndex and OFAuctionFrameBrowse.selectedCategoryIndex == categoryIndex;
        local blueHighlight = categoryInfo:HasFlag("BLUE_HIGHLIGHT")
        tinsert(OF_OPEN_FILTER_LIST, { name = categoryInfo.name, type = "category", categoryIndex = categoryIndex, selected = selected, isToken = false, blueHighlight=blueHighlight });

        if ( selected ) then
            OFAuctionFrameFilters_AddSubCategories(categoryInfo.subCategories);
        end
	end
	
	local hasScrollBar = #OF_OPEN_FILTER_LIST > OF_NUM_FILTERS_TO_DISPLAY;

	-- Display the list of open filters
	local offset = FauxScrollFrame_GetOffset(OFBrowseFilterScrollFrame);
	if ( forceSelectionIntoView and hasScrollBar and OFAuctionFrameBrowse.selectedCategoryIndex and ( not OFAuctionFrameBrowse.selectedSubCategoryIndex and not OFAuctionFrameBrowse.selectedSubSubCategoryIndex ) ) then
		if ( OFAuctionFrameBrowse.selectedCategoryIndex <= offset ) then
			FauxScrollFrame_OnVerticalScroll(OFBrowseFilterScrollFrame, math.max(0.0, (OFAuctionFrameBrowse.selectedCategoryIndex - 1) * OF_BROWSE_FILTER_HEIGHT), OF_BROWSE_FILTER_HEIGHT);
			offset = FauxScrollFrame_GetOffset(OFBrowseFilterScrollFrame);
		end
	end
	
	local dataIndex = offset;

	for i = 1, OF_NUM_FILTERS_TO_DISPLAY do
		local button = OFAuctionFrameBrowse.OFFilterButtons[i];
		button:SetWidth(hasScrollBar and 136 or 156);

		dataIndex = dataIndex + 1;

		if ( dataIndex <= #OF_OPEN_FILTER_LIST ) then
			local info = OF_OPEN_FILTER_LIST[dataIndex];

			if ( info ) then
				OFFilterButton_SetUp(button, info);
				
				if ( info.type == "category" ) then
					button.categoryIndex = info.categoryIndex;
				elseif ( info.type == "subCategory" ) then
					button.subCategoryIndex = info.subCategoryIndex;
				elseif ( info.type == "subSubCategory" ) then
					button.subSubCategoryIndex = info.subSubCategoryIndex;
				end
				
				if ( info.selected ) then
					button:LockHighlight();
				else
					button:UnlockHighlight();
				end
				button:Show();
			end
		else
			button:Hide();
		end
	end
end

function OFAuctionFrameFilters_AddSubCategories(subCategories)
	if subCategories then
		for subCategoryIndex, subCategoryInfo in ipairs(subCategories) do
			local selected = OFAuctionFrameBrowse.selectedSubCategoryIndex and OFAuctionFrameBrowse.selectedSubCategoryIndex == subCategoryIndex;

			tinsert(OF_OPEN_FILTER_LIST, { name = subCategoryInfo.name, type = "subCategory", subCategoryIndex = subCategoryIndex, selected = selected });
		 
			if ( selected ) then
				OFAuctionFrameFilters_AddSubSubCategories(subCategoryInfo.subCategories);
			end
		end
	end
end

function OFAuctionFrameFilters_AddSubSubCategories(subSubCategories)
	if subSubCategories then
		for subSubCategoryIndex, subSubCategoryInfo in ipairs(subSubCategories) do
			local selected = OFAuctionFrameBrowse.selectedSubSubCategoryIndex and OFAuctionFrameBrowse.selectedSubSubCategoryIndex == subSubCategoryIndex;
			local isLast = subSubCategoryIndex == #subSubCategories;

			tinsert(OF_OPEN_FILTER_LIST, { name = subSubCategoryInfo.name, type = "subSubCategory", subSubCategoryIndex = subSubCategoryIndex, selected = selected, isLast = isLast});
		end
	end
end

function OFFilterButton_SetUp(button, info)
	local normalText = _G[button:GetName().."NormalText"];
	local normalTexture = _G[button:GetName().."NormalTexture"];
	local line = _G[button:GetName().."Lines"];
	local tex = button:GetNormalTexture();

	if ( info.type == "category" ) then
		button:SetNormalFontObject(GameFontNormalSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 4, 0);
		normalTexture:SetAlpha(1.0);	
		line:Hide();
	elseif ( info.type == "subCategory" ) then
		button:SetNormalFontObject(GameFontHighlightSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 12, 0);
		normalTexture:SetAlpha(0.4);
		line:Hide();
	elseif ( info.type == "subSubCategory" ) then
		button:SetNormalFontObject(GameFontHighlightSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 20, 0);
		normalTexture:SetAlpha(0.0);	
		
		if ( info.isLast ) then
			line:SetTexCoord(0.4375, 0.875, 0, 0.625);
		else
			line:SetTexCoord(0, 0.4375, 0, 0.625);
		end
		line:Show();
	end
	button.type = info.type; 
end

function OFAuctionFrameFilter_OnClick(self, button)
	if ( self.type == "category" ) then
		if ( OFAuctionFrameBrowse.selectedCategoryIndex == self.categoryIndex ) then
			OFAuctionFrameBrowse.selectedCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedCategoryIndex = self.categoryIndex;
            local sortParams = currentSortParams["list"]
            if sortParams and sortParams.column == "quality" and sortParams.desc then
                OFAuctionFrame_SetSort("list", "quality", false)
            end
		end
		OFAuctionFrameBrowse.selectedSubCategoryIndex = nil;
		OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
	elseif ( self.type == "subCategory" ) then
		if ( OFAuctionFrameBrowse.selectedSubCategoryIndex == self.subCategoryIndex ) then
			OFAuctionFrameBrowse.selectedSubCategoryIndex = nil;
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedSubCategoryIndex = self.subCategoryIndex;
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		end
	elseif ( self.type == "subSubCategory" ) then
		if ( OFAuctionFrameBrowse.selectedSubSubCategoryIndex == self.subSubCategoryIndex ) then
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = self.subSubCategoryIndex
		end
	end
	OFAuctionFrameFilters_Update(true)
end

local function UpdateItemIcon(itemID, buttonName, texture, count, canUse)
    local iconTexture = _G[buttonName.."ItemIconTexture"];
    iconTexture:SetTexture(texture);
    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    end
    local itemCount = _G[buttonName.."ItemCount"];
    if count > 1 and itemID ~= ns.ITEM_ID_GOLD then
        itemCount:SetText(count);
        itemCount:Show();
    else
        itemCount:Hide();
    end
end


local function UpdateItemName(quality, buttonName, name)
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality];
    local itemName = _G[buttonName.."Name"];
    itemName:SetText(name);
    itemName:SetVertexColor(color.r, color.g, color.b);
end

local function ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries)
    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[button:GetName().."Highlight"]
    if ( numBatchAuctions < OF_NUM_BROWSE_TO_DISPLAY ) then
        button:SetWidth(625);
        buttonHighlight:SetWidth(589);
        OFBrowseCurrentBidSort:SetWidth(126);
    elseif ( numBatchAuctions == OF_NUM_BROWSE_TO_DISPLAY and totalEntries <= OF_NUM_BROWSE_TO_DISPLAY ) then
        button:SetWidth(625);
        buttonHighlight:SetWidth(589);
        OFBrowseCurrentBidSort:SetWidth(126);
    else
        button:SetWidth(600);
        buttonHighlight:SetWidth(562);
        OFBrowseCurrentBidSort:SetWidth(102);
    end
end

local function ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries)
    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[button:GetName().."Highlight"];
    if ( numBatchAuctions < OF_NUM_AUCTIONS_TO_DISPLAY ) then
        button:SetWidth(599);
        buttonHighlight:SetWidth(565);
    elseif ( numBatchAuctions == OF_NUM_AUCTIONS_TO_DISPLAY and totalEntries <= OF_NUM_AUCTIONS_TO_DISPLAY ) then
        button:SetWidth(599);
        buttonHighlight:SetWidth(565);
    else
        button:SetWidth(576);
        buttonHighlight:SetWidth(543);
    end
end

local function UpdateItemEntry(index, i, offset, button, item, numBatchAuctions, totalEntries, entryType)
    local icon
    local isGold = item.id == ns.ITEM_ID_GOLD
    if isGold then
        icon = item.icon
    else
        icon = select(5, ns.GetItemInfoInstant(item.id))
    end
    local name = item.name
    local quality = item.quality
    local level = item.level
    local buttonName = button:GetName()

    button:Show();

    if entryType == "list" then
        ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries, entryType)
    elseif entryType == "owner" then
        ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries, entryType)
    end

    UpdateItemName(quality, buttonName, name)

    UpdateItemIcon(item.id, buttonName, icon, 1, true)

    local function Hide(name)
        local frame = _G[buttonName..name]
        if frame then
            frame:Hide()
        end
    end

    Hide("AuctionType")
    Hide("DeliveryType")
    Hide("HighBidder")
    Hide("MoneyFrame")

    _G[buttonName.."RequestItem"]:Show()

    local levelText = _G[buttonName.."Level"]
    if isGold or ns.IsSpellItem(item.id) then
        levelText:SetText("")
    else
        levelText:SetText(level)
    end

    Hide("DeathRollIcon")
    Hide("PriceText")
    Hide("RatingFrame")

    button.buyoutPrice = 0
    button.itemCount = 1
    button.itemIndex = index
    button.itemID = item.id
    button.item = item
    button.isEnchantEntry = false
    button.auction = nil
    button:UnlockHighlight()
end

local function UpdateEnchantAuctionEntry(index, i, offset, button, numBatchAuctions, totalEntries)
    local icon = "Interface/Icons/Spell_holy_greaterheal"
    local name = "Enchants"
    local quality = 1
    local buttonName = button:GetName()

    button:Show()

    ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries)

    UpdateItemName(quality, buttonName, L["Enchants"])

    UpdateItemIcon(0, buttonName, icon, 1, true)

    local function Hide(name)
        local frame = _G[buttonName..name]
        if frame then
            frame:Hide()
        end
    end

    Hide("AuctionType")
    Hide("DeliveryType")
    Hide("HighBidder")
    Hide("MoneyFrame")

    _G[buttonName.."RequestItem"]:Show()

    local levelText = _G[buttonName.."Level"]
    levelText:SetText("")

    Hide("DeathRollIcon")
    Hide("PriceText")
    Hide("RatingFrame")

    button.buyoutPrice = 0
    button.itemCount = 1
    button.itemIndex = index
    button.itemID = 0
    button.isEnchantEntry = true
    button:UnlockHighlight()
end


local function UpdateDeliveryType(buttonName, auction)
    local deliveryTypeFrame = _G[buttonName.."DeliveryType"];
    local deliveryTypeText = _G[buttonName.."DeliveryTypeText"];
    local deliveryTypeNoteIcon = _G[buttonName.."DeliveryTypeNoteIcon"];

    deliveryTypeText:SetText(ns.GetDeliveryTypeDisplayString(auction))
    deliveryTypeFrame.tooltip = ns.GetDeliveryTypeTooltip(auction)
    if auction.note and auction.note ~= "" then
        deliveryTypeNoteIcon:Show()
        deliveryTypeText:SetPoint("TOPLEFT", deliveryTypeFrame, "TOPLEFT", 14, 0)
    else
        deliveryTypeNoteIcon:Hide()
        deliveryTypeText:SetPoint("TOPLEFT", deliveryTypeFrame, "TOPLEFT", 0, 0)
    end
    deliveryTypeFrame:Show()
end

local function UpdatePrice(buttonName, auction)
    local button = _G[buttonName]
    local moneyFrame = _G[buttonName.."MoneyFrame"]
    local priceText = _G[buttonName.."PriceText"]
    local tipFrame = _G[buttonName.."TipMoneyFrame"]
    local deathRollIcon = _G[buttonName.."DeathRollIcon"]
    if tipFrame then
        tipFrame:Hide()
    end

    if auction.deathRoll or auction.duel then
        deathRollIcon:Show()
        MoneyFrame_Update(moneyFrame, auction.price)
        local iconXOffset
        if auction.deathRoll then
            priceText:SetText(L["Death Roll"])
            deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\icons\\Icn_DeathRoll")
            iconXOffset = -60
        else
            priceText:SetText(L["Duel (Normal)"])
            iconXOffset = -80
            deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\icons\\Icn_Duel")
        end
        priceText:SetJustifyH("RIGHT")
        if auction.itemID == ns.ITEM_ID_GOLD then
            moneyFrame:Hide()
            priceText:SetPoint("RIGHT", button, "RIGHT", -5, 3)
            deathRollIcon:SetPoint("RIGHT", button, "RIGHT", iconXOffset, 3)
        else
            deathRollIcon:SetPoint("RIGHT", button, "RIGHT", iconXOffset, 10)
            priceText:SetPoint("RIGHT", button, "RIGHT", -5, 10)
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, -4)
            moneyFrame:Show()
        end
        priceText:Show()
    elseif auction.priceType == ns.PRICE_TYPE_MONEY then
        deathRollIcon:Hide()
        priceText:Hide()
        moneyFrame:Show()
        MoneyFrame_Update(moneyFrame, auction.price)
        if auction.tip > 0 and tipFrame then
            tipFrame:Show()
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, 10)
            MoneyFrame_Update(_G[tipFrame:GetName().."Money"], auction.tip)
        else
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, 3)
        end
    elseif auction.priceType == ns.PRICE_TYPE_TWITCH_RAID then
        deathRollIcon:Hide()
        priceText:SetJustifyH("CENTER")
        priceText:SetPoint("RIGHT", button, "RIGHT", 0, 3)
        priceText:SetText(string.format(L["Twitch Raid %d+"], auction.raidAmount))
        priceText:Show()
        moneyFrame:Hide()
    elseif auction.priceType == ns.PRICE_TYPE_GUILD_POINTS then
        deathRollIcon:Hide()
        priceText:SetJustifyH("CENTER")
        priceText:SetPoint("RIGHT", button, "RIGHT", 0, 3)
        priceText:SetText(string.format(L["%d Points"], auction.points))
        priceText:Show()
        moneyFrame:Hide()
    else
        deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\Icn_Note02")
        deathRollIcon:SetPoint("RIGHT", button, "RIGHT", -47, 3)
        deathRollIcon:Show()
        priceText:SetJustifyH("RIGHT")
        priceText:SetPoint("RIGHT", button, "RIGHT", -5, 3)
        priceText:SetText("Custom")  -- not localized because the exclamation icon is hardcoded, and the Spanish word is much longer
        priceText:Show()
        moneyFrame:Hide()
    end
end

local function UpdateBrowseEntry(index, i, offset, button, auction, numBatchAuctions, totalEntries)
    local name, _, quality, level, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local owner = auction.owner
    local ownerFullName = auction.owner
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show()

    local buttonName = "OFBrowseButton"..i

    ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries)

    UpdateItemName(quality, buttonName, name)
    local itemButton = _G[buttonName.."Item"]

    _G[buttonName.."RequestItem"]:Hide()

    _G[buttonName.."AuctionTypeText"]:SetText(ns.GetAuctionTypeDisplayString(auction.auctionType))
    _G[buttonName.."AuctionType"]:Show()

    _G[buttonName.."Level"]:SetText(level)

    local ratingFrame = _G[buttonName.."RatingFrame"]
    ratingFrame:Show()
    ratingFrame.ratingWidget:SetRating(ns.AuctionHouseAPI:GetAverageRatingForUser(auction.owner))

    UpdateDeliveryType(buttonName, auction)

    UpdateItemIcon(auction.itemID, buttonName, texture, count, canUse)

    UpdatePrice(buttonName, auction)
    MoneyFrame_SetMaxDisplayWidth(_G[buttonName.."MoneyFrame"], 100)

    local ownerFrame = _G[buttonName.."HighBidder"]
    ownerFrame.fullName = ownerFullName
    ownerFrame.Name:SetText(ns.GetDisplayName(owner))
    ownerFrame:Show()

    -- this is for comparing to the player name to see if they are the owner of this auction
    local ownerName;
    if (not ownerFullName) then
        ownerName = owner
    else
        ownerName = ownerFullName
    end

    button.auction = auction
    button.buyoutPrice = buyoutPrice
    button.itemCount = count
    button.itemIndex = index
    button.itemID = auction.itemID
    -- Set highlight
    local selected = OFGetSelectedAuctionItem("list")
    if ( selected and selected.id == auction.id) then
        button:LockHighlight()

        local canBuyout = 1
        if ( GetMoney() < buyoutPrice ) then
            canBuyout = nil
        end
        if auction.priceType == ns.PRICE_TYPE_GUILD_POINTS and ns.GetGuildPoints(UnitName("player")) < auction.points then
            canBuyout = nil
        end
        if ( (ownerName ~= UnitName("player")) ) then
            if auction.auctionType == ns.AUCTION_TYPE_BUY then
                if ns.GetItemCount(auction.itemID, true) >= auction.quantity then
                    OFBrowseFulfillButton:Enable()
                end
            else
                if canBuyout then
                    OFBrowseBuyoutButton:Enable()
                end
                if auction.allowLoan then
                    OFBrowseLoanButton:Enable()
                end
            end
            OFAuctionFrame.buyoutPrice = buyoutPrice
            OFAuctionFrame.auction = auction
        end
    else
        button:UnlockHighlight()
    end

    if ( button.PriceTooltipFrame == activeTooltipPriceTooltipFrame ) then
        OFAuctionPriceTooltipFrame_OnEnter(button.PriceTooltipFrame)
    elseif ( itemButton == activeTooltipAuctionFrameItem ) then
        OFAuctionFrameItem_OnEnter(itemButton, "list")
    end
end

function OFAuctionFrameBrowse_Update()
    local auctions, items
    if browseResultCache ~= nil then
        auctions, items = browseResultCache.auctions, browseResultCache.items
    else
        auctions = ns.GetBrowseAuctions(prevBrowseParams or BrowseParams.Empty())
        if prevBrowseParams and not ns.IsDefaultBrowseParams(prevBrowseParams) then
            items = ns.ItemDB:Find(ns.BrowseParamsToItemDBArgs(prevBrowseParams))
            -- Filter out items that are in ns.itemsBoP
            local filteredItems = {}
            for _, item in ipairs(items) do
                if item.id and not ns.itemsBoP[item.id] then
                    table.insert(filteredItems, item)
                end
            end
            items = ns.FilterItemsExtra(filteredItems, prevBrowseParams)
        else
            items = {}
        end
        browseResultCache = { auctions = auctions, items = items }
        browseSortDirty = true
    end
    if browseSortDirty then
        local sortParams = currentSortParams["list"].params
        auctions = ns.SortAuctions(auctions, sortParams)
        items = ns.SortAuctions(items, sortParams)
        browseResultCache = { auctions = auctions, items = items }
        browseSortDirty = false
    end

    local totalEntries = #auctions + #items
    -- gold item always the first item
    totalEntries = totalEntries + 1
    local numBatchAuctions = min(totalEntries, OF_NUM_AUCTION_ITEMS_PER_PAGE)
    local button;
    local offset = FauxScrollFrame_GetOffset(OFBrowseScrollFrame);
    local index;
    local isLastSlotEmpty;
    local hasAllInfo, itemName;
    OFBrowseBuyoutButton:Show();
    OFBrowseLoanButton:Show();
    OFBrowseBuyoutButton:Disable();
    OFBrowseLoanButton:Disable();
    OFBrowseFulfillButton:Disable();
    -- Update sort arrows
    OFAuctionFrameBrowse_UpdateArrows();

    -- Show the no results text if no items found
    if ( numBatchAuctions == 0 ) then
        OFBrowseNoResultsText:Show();
    else
        OFBrowseNoResultsText:Hide();
    end

    for i=1, OF_NUM_BROWSE_TO_DISPLAY do
        index = offset + i + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameBrowse.page);
        button = _G["OFBrowseButton"..i];
        local auction = auctions[index - 1]
        local shouldHide = not auction or index > (numBatchAuctions + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameBrowse.page));
        if ( not shouldHide ) then
            itemName = ns.GetItemInfo(auction.itemID, auction.quantity)
            hasAllInfo = itemName ~= nil and auction ~= nil
            if ( not hasAllInfo ) then --Bug  145328
                shouldHide = true;
            end
        end

        if ( auction ) then
            button.auctionId = auction.id
        else
            button.auctionId = nil
        end
        local isItem = index == 1 or ((index > (#auctions + 1) and (index - 1 - #auctions) <= #items))
        -- Show or hide auction buttons
        if isItem then
            auction = nil
            local item
            if index == 1 then
                item = ns.ITEM_GOLD
            else
                item = items[index - 1 - #auctions]
            end
            ns.TryExcept(
                function() UpdateItemEntry(index, i, offset, button, item, numBatchAuctions, totalEntries, "list") end,
                function(err)
                    button:Hide()
                    ns.DebugLog("Browse UpdateItemEntry failed: ", err)
                end
            )

        elseif ( shouldHide ) then
            button:Hide();
            -- If the last button is empty then set isLastSlotEmpty var
            if ( i == OF_NUM_BROWSE_TO_DISPLAY ) then
                isLastSlotEmpty = 1;
            end
            if auction ~= nil and itemName == nil then
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFBrowseButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                            function() UpdateBrowseEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalEntries) end,
                            function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred browse entry failed: ", err) end
                        )
                    end
                end)
            end
        else
            ns.TryExcept(
                function() UpdateBrowseEntry(index, i, offset, button, auction, numBatchAuctions, totalEntries) end,
                function(err) button:Hide(); ns.DebugLog("rendering browse entry failed: ", err) end
            )
        end
    end

    -- Update scrollFrame
    -- If more than one page of auctions, show the next and prev arrows and show the item ranges of the active page
    --  when page the scrollframe is scrolled all the way down
    if ( totalEntries > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
        OFBrowsePrevPageButton.isEnabled = (OFAuctionFrameBrowse.page ~= 0);
        OFBrowseNextPageButton.isEnabled = (OFAuctionFrameBrowse.page ~= (ceil(totalEntries /OF_NUM_AUCTION_ITEMS_PER_PAGE) - 1));
        if ( isLastSlotEmpty ) then
            OFBrowseSearchCountText:Show();
            local itemsMin = OFAuctionFrameBrowse.page * OF_NUM_AUCTION_ITEMS_PER_PAGE + 1;
            local itemsMax = itemsMin + numBatchAuctions - 1;
            OFBrowseSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalEntries);
        else
            OFBrowseSearchCountText:Hide();
        end

        -- Artifically inflate the number of results so the scrollbar scrolls one extra row
        numBatchAuctions = numBatchAuctions + 1;
    else
        OFBrowsePrevPageButton.isEnabled = false;
        OFBrowseNextPageButton.isEnabled = false;
        OFBrowseSearchCountText:Hide();
    end
    FauxScrollFrame_Update(OFBrowseScrollFrame, numBatchAuctions, OF_NUM_BROWSE_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT);
end

local function UpdatePendingEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions)
    local name, _, quality, _, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show()

    local buttonName = "OFBidButton"..i

    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[buttonName.."Highlight"];
    if ( numBatchAuctions < OF_NUM_BIDS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    elseif ( numBatchAuctions == OF_NUM_BIDS_TO_DISPLAY and totalAuctions <= OF_NUM_BIDS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    else
        button:SetWidth(769)
        buttonHighlight:SetWidth(735)
    end
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality] or { r = 255, g = 255, b = 255 }
    local itemName = _G[buttonName.."Name"]
    itemName:SetText(name)
    itemName:SetVertexColor(color.r, color.g, color.b)


    local otherUserText = _G[buttonName.."BidBuyer"]
    local otherUser
    if auction.owner == UnitName("player") then
        otherUser = auction.buyer
    else
        otherUser = auction.owner
    end
    otherUserText:SetText(ns.GetDisplayName(otherUser))

    local statusText = _G[buttonName.."BidStatus"]
    statusText:SetText(ns.GetAuctionStatusDisplayString(auction))

    -- Set item texture, count, and usability
    local iconTexture = _G[buttonName.."ItemIconTexture"]
    iconTexture:SetTexture(texture)
    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1)
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0)
    end
    local itemCount = _G[buttonName.."ItemCount"]
    if auction.itemID ~= ns.ITEM_ID_GOLD and count > 1 then
        itemCount:SetText(count)
        itemCount:Show()
    else
        itemCount:Hide()
    end

    UpdateDeliveryType(buttonName, auction)

    local auctionType = auction.wish and ns.AUCTION_TYPE_BUY or ns.AUCTION_TYPE_SELL
    local auctionTypeText = _G[buttonName.."AuctionTypeText"]
    auctionTypeText:SetText(ns.GetAuctionTypeDisplayString(auctionType))

    _G[buttonName.."RatingFrame"].ratingWidget:SetRating(ns.AuctionHouseAPI:GetAverageRatingForUser(otherUser))

    local statusTooltip = _G[buttonName.."StatusTooltipFrame"]
    statusTooltip.tooltip = ns.GetAuctionStatusTooltip(auction)

    -- Set buyout price
    UpdatePrice(buttonName, auction)

    button.buyoutPrice = buyoutPrice;
    button.itemCount = count;
    button.itemID = auction.itemID
    button.auction = auction

    -- Set highlight
    local selected = OFGetSelectedAuctionItem("bidder")
    if ( selected and selected.id == auction.id) then
        button:LockHighlight();
        local me = UnitName("player")
        local isOwner
        if auction.wish then
            isOwner = auction.buyer == me
        else
            isOwner = auction.owner == me
        end
        local otherMember = auction.owner == me and auction.buyer or auction.owner
        if ns.GuildRegister:IsMemberOnline(otherMember) then
            OFBidWhisperButton:Enable()
            OFBidInviteButton:Enable()
        end
        local isLoan = auction.status == ns.AUCTION_STATUS_SENT_LOAN or auction.status == ns.AUCTION_STATUS_PENDING_LOAN
        if ns.IsSpellItem(auction.itemID) then
            OFBidForgiveLoanButtonText:SetText(L["Mark Auction Complete"])
            if auction.owner == me then
                OFBidForgiveLoanButton:Enable()
            end
        elseif isLoan and auction.owner ~= me then
            OFBidForgiveLoanButtonText:SetText(L["Declare Bankruptcy"])
            if auction.status == ns.AUCTION_STATUS_SENT_LOAN then
                OFBidForgiveLoanButton:Enable()
            end
        else
            OFBidForgiveLoanButtonText:SetText(L["Mark Loan Complete"])
        end

        if not isOwner then
            -- auction can't be cancelled
        elseif auction.status == ns.AUCTION_STATUS_SENT_LOAN then
            OFBidForgiveLoanButton:Enable()
        elseif auction.status == ns.AUCTION_STATUS_SENT_COD then
            -- auction can't be cancelled
        else
            OFBidCancelAuctionButton:Enable()
        end
        OFAuctionFrame.buyoutPrice = buyoutPrice;
        OFAuctionFrame.auction = auction
    else
        button:UnlockHighlight();
    end
end

function OFAuctionFrameBid_OnLoad()
    OFAuctionFrame_SetSort("bidder", "quality", false);
    local callback = function(...)
        if OFAuctionFrame:IsShown() and OFAuctionFrameBid:IsShown() then
            OFAuctionFrameBid_Update();
        end
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, callback)
end

function OFAuctionFrameBid_Update()
    local auctions = ns.GetMyPendingAuctions(currentSortParams["bidder"].params)
    local totalAuctions = #auctions
    local numBatchAuctions = min(totalAuctions, OF_NUM_AUCTION_ITEMS_PER_PAGE)
	local button, auction
	local offset = FauxScrollFrame_GetOffset(OFBidScrollFrame);
	local index;
	local isLastSlotEmpty;
    OFBidCancelAuctionButton:Disable()
    OFBidForgiveLoanButton:Disable()
    OFBidWhisperButton:Disable()
    OFBidInviteButton:Disable()

    -- Update sort arrows
	OFSortButton_UpdateArrow(OFBidQualitySort, "bidder", "quality")
    OFSortButton_UpdateArrow(OFBidTypeSort, "bidder", "type")
    OFSortButton_UpdateArrow(OFBidDeliverySort, "bidder", "delivery")
    OFSortButton_UpdateArrow(OFBidBuyerName, "bidder", "buyer")
    OFSortButton_UpdateArrow(OFBidRatingSort, "bidder", "rating")
    OFSortButton_UpdateArrow(OFBidStatusSort, "bidder", "status")
	OFSortButton_UpdateArrow(OFBidBidSort, "bidder", "bid")

	for i=1, OF_NUM_BIDS_TO_DISPLAY do
		index = offset + i;
		button = _G["OFBidButton"..i]

        auction = auctions[index]
        if (auction) then
            button.auctionId = auction.id
        else
            button.auctionId = nil
        end
		-- Show or hide auction buttons
		if ( auction == nil or index > numBatchAuctions ) then
			button:Hide();
			-- If the last button is empty then set isLastSlotEmpty var
			isLastSlotEmpty = (i == OF_NUM_BIDS_TO_DISPLAY);
		else
			button:Show()
            local itemName = ns.GetItemInfo(auction.itemID)
            if (itemName) then
                ns.TryExcept(
                        function() UpdatePendingEntry(index, i, offset, button, auctions[index], numBatchAuctions, totalAuctions) end,
                        function(err) button:Hide(); ns.DebugLog("rendering pending entry failed: ", err) end
                )
            else
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFBidButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                                function() UpdatePendingEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalAuctions) end,
                                function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred pending entry failed: ", err) end
                        )
                    end
                end)
            end
		end
	end
	-- If more than one page of auctions show the next and prev arrows when the scrollframe is scrolled all the way down
	if ( totalAuctions > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
		if ( isLastSlotEmpty ) then
			OFBidSearchCountText:Show()
			OFBidSearchCountText:SetFormattedText(SINGLE_PAGE_RESULTS_TEMPLATE, totalAuctions)
		else
			OFBidSearchCountText:Hide()
		end
		
		-- Artifically inflate the number of results so the scrollbar scrolls one extra row
		numBatchAuctions = numBatchAuctions + 1
	else
		OFBidSearchCountText:Hide()
	end

	-- Update scrollFrame
	FauxScrollFrame_Update(OFBidScrollFrame, numBatchAuctions, OF_NUM_BIDS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
end

function OFBidButton_OnClick(button)
	assert(button)
	
	OFSetSelectedAuctionItem("bidder", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameBid_Update()
end

function OFIsGoldItemSelected()
    local itemID = select(10, OFGetAuctionSellItemInfo())
    return itemID == ns.ITEM_ID_GOLD
end

function OFIsSpellItemSelected()
    local itemID = select(10, OFGetAuctionSellItemInfo())
    return itemID and ns.IsSpellItem(itemID)
end
-- OFAuctions tab functions
-- Delivery Dropdown
function OFDeliveryDropdown_Initialize(self, level)
    local info = UIDropDownMenu_CreateInfo()
    local parent = self:GetParent() or self  -- Fallback to self if no parent
    
    -- Use the global function, not a method
    local isSpellSelected = OFIsSpellItemSelected()
    
    -- "Any" option (if spell/item is NOT selected)
    if not isSpellSelected then
        info.text = "Any"
        info.value = ns.DELIVERY_TYPE_ANY
        info.func = function()
            parent:SetDeliverySelected(ns.DELIVERY_TYPE_ANY)
            UIDropDownMenu_SetSelectedValue(OFDeliveryDropdown, ns.DELIVERY_TYPE_ANY)
        end
        info.checked = parent:IsDeliverySelected(ns.DELIVERY_TYPE_ANY)
        UIDropDownMenu_AddButton(info)

        -- "Mail" option
        info.text = "Mail"
        info.value = ns.DELIVERY_TYPE_MAIL
        info.func = function()
            parent:SetDeliverySelected(ns.DELIVERY_TYPE_MAIL)
            UIDropDownMenu_SetSelectedValue(OFDeliveryDropdown, ns.DELIVERY_TYPE_MAIL)
        end
        info.checked = parent:IsDeliverySelected(ns.DELIVERY_TYPE_MAIL)
        UIDropDownMenu_AddButton(info)
    end

    -- "Trade" option (always available)
    info.text = "Trade"
    info.value = ns.DELIVERY_TYPE_TRADE
    info.func = function()
        parent:SetDeliverySelected(ns.DELIVERY_TYPE_TRADE)
        UIDropDownMenu_SetSelectedValue(OFDeliveryDropdown, ns.DELIVERY_TYPE_TRADE)
    end
    info.checked = parent:IsDeliverySelected(ns.DELIVERY_TYPE_TRADE)
    UIDropDownMenu_AddButton(info)
end

-- Price Type Dropdown
function OFPriceTypeDropdown_Initialize(self, level)
    local info = UIDropDownMenu_CreateInfo()
    local parent = self:GetParent() or self  -- Fallback to self if no parent
    
    -- Use the global function, not a method
    local isGoldSelected = OFIsGoldItemSelected()

    -- Gold option (if enabled)
    if not isGoldSelected then
        info.text = "Gold"
        info.value = ns.PRICE_TYPE_MONEY
        info.func = function() 
            parent:SetPriceSelected(ns.PRICE_TYPE_MONEY)
            UIDropDownMenu_SetSelectedValue(OFPriceTypeDropdown, ns.PRICE_TYPE_MONEY)
        end
        info.checked = parent:IsPriceSelected(ns.PRICE_TYPE_MONEY)
        UIDropDownMenu_AddButton(info)
    end

    -- Twitch Raid option
    info.text = "Twitch Raid"
    info.value = ns.PRICE_TYPE_TWITCH_RAID
    info.func = function()
        parent:SetPriceSelected(ns.PRICE_TYPE_TWITCH_RAID)
        UIDropDownMenu_SetSelectedValue(OFPriceTypeDropdown, ns.PRICE_TYPE_TWITCH_RAID)
    end
    info.checked = parent:IsPriceSelected(ns.PRICE_TYPE_TWITCH_RAID)
    UIDropDownMenu_AddButton(info)

    -- Custom option
    info.text = "Custom"
    info.value = ns.PRICE_TYPE_CUSTOM
    info.func = function()
        parent:SetPriceSelected(ns.PRICE_TYPE_CUSTOM)
        UIDropDownMenu_SetSelectedValue(OFPriceTypeDropdown, ns.PRICE_TYPE_CUSTOM)
    end
    info.checked = parent:IsPriceSelected(ns.PRICE_TYPE_CUSTOM)
    UIDropDownMenu_AddButton(info)
end

function OFSetupPriceTypeDropdown(self)
    self.isGoldSelected = OFIsGoldItemSelected()
    if self.isGoldSelected then
        self.priceTypeIndex = ns.PRICE_TYPE_CUSTOM
    else
        self.priceTypeIndex = ns.PRICE_TYPE_MONEY
    end

    self.IsPriceSelected = function(frame, index)
        return frame.priceTypeIndex == index
    end

    self.SetPriceSelected = function(frame, index)
        if index ~= ns.PRICE_TYPE_MONEY then
            allowLoans = false
            deathRoll = false
            duel = false
        end
        frame.priceTypeIndex = index
        OFUpdateAuctionSellItem()
    end

    UIDropDownMenu_Initialize(OFPriceTypeDropdown, OFPriceTypeDropdown_Initialize)
    local SelectedPriceType = self.isGoldSelected and ns.PRICE_TYPE_CUSTOM or ns.PRICE_TYPE_MONEY
    UIDropDownMenu_SetSelectedValue(OFPriceTypeDropdown, SelectedPriceType)
end

function OFSetupDeliveryDropdown(self, overrideDeliveryType)
    self.isSpellSelected = OFIsSpellItemSelected()
    if self.isSpellSelected then
        self.deliveryTypeIndex = ns.DELIVERY_TYPE_TRADE
    else
        self.deliveryTypeIndex = overrideDeliveryType or ns.DELIVERY_TYPE_ANY
    end

    self.IsDeliverySelected = function(frame, index)
        return frame.deliveryTypeIndex == index
    end

    self.SetDeliverySelected = function(frame, index)
        frame.deliveryTypeIndex = index
        if index ~= ns.DELIVERY_TYPE_TRADE then
            deathRoll = false
            duel = false
            roleplay = false
            OFUpdateAuctionSellItem()
        end
    end

    UIDropDownMenu_Initialize(OFDeliveryDropdown, OFDeliveryDropdown_Initialize)
    local SelectedDelivery = self.isSpellSelected and ns.DELIVERY_TYPE_TRADE or ns.DELIVERY_TYPE_ANY
    UIDropDownMenu_SetSelectedValue(OFDeliveryDropdown, SelectedDelivery)
end

function OFAuctionFrameAuctions_OnLoad(self)
    local callback = function(...)
        if OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
            OFAuctionFrameAuctions_Update();
        end
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, callback)
    -- set default sort
    OFAuctionFrame_SetSort("owner", "duration", false);

    OFSetupPriceTypeDropdown(self)
    OFSetupDeliveryDropdown(self)

    hooksecurefunc(_G, "ContainerFrameItemButton_OnModifiedClick", function(item, button, ...)
        if button == "RightButton" and IsShiftKeyDown() and OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
            local bagIdx, slotIdx = item:GetParent():GetID(), item:GetID()
            C_Container.PickupContainerItem(bagIdx, slotIdx);
            OFAuctionSellItemButton_OnClick(OFAuctionsItemButton, "LeftButton")
        end
        if button == "LeftButton" and IsShiftKeyDown() and OFAuctionFrame:IsShown() and OFAuctionFrameBrowse:IsShown() then
            local bagIdx, slotIdx = item:GetParent():GetID(), item:GetID()
            local itemName = C_Container.GetContainerItemInfo(bagIdx, slotIdx).itemName
            if itemName then
                OFBrowseName:SetText(itemName)
                OFBrowseName:SetTextColor(1, 1, 1)
                OFAuctionFrameBrowse_Search()
            end
        end
    end)

    -- **Styling OFAuctionsItemButton using SetBackdrop:**
    local button = OFAuctionsItemButton;

    -- Set Backdrop Properties
    button:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Border texture
        edgeSize = 16,                                       -- Border size in pixels
        insets = { left = 4, right = 4, top = 4, bottom = 4 }, -- Insets for the content within the border
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", -- Background texture (optional, can also use color)
    });

    -- Set Backdrop Border Color
    button:SetBackdropBorderColor(0, 0, 0);       -- Black border (R, G, B, Alpha - Alpha defaults to 1 if not specified)

    -- Set Backdrop Background Color (optional, if you want a solid background color instead of bgFile texture)
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.8);  -- Dark grey background with some transparency (R, G, B, Alpha)

    -- If you ONLY want a border and no background texture or color, you can comment out or remove `bgFile` and `SetBackdropColor`.
end

function OFAuctionFrameAuctions_OnEvent(self, event, ...)
	if ( event == "AUCTION_OWNED_LIST_UPDATE") then
		OFAuctionFrameAuctions_Update();
	end
end

local function DeselectAuctionItem()
    if not OFGetAuctionSellItemInfo() then
        return
    end

    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    UnlockCheckButton(OFAllowLoansCheckButton)
    local prev = GetCVar("Sound_EnableSFX")
    SetCVar("Sound_EnableSFX", 0)
    ns.TryFinally(
            function()
                ClearCursor()
                ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
                ClearCursor()
                auctionSellItemInfo = nil
                OFUpdateAuctionSellItem()
            end,
            function()
                SetCVar("Sound_EnableSFX", prev)
            end
    )
end

function OFAuctionFrameAuctions_OnHide(self)
    DeselectAuctionItem()
end

function OFAuctionFrameAuctions_OnShow()
    OFAuctionsTitle:SetFormattedText(L["GoAgain AH - %s's Auctions"], UnitName("player"))
    OFAuctionsFrameAuctions_ValidateAuction()
    OFAuctionFrameAuctions_Update()

end

local function UpdateAuctionEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions)
    local name, _, quality, level, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show();

    local buttonName = "OFAuctionsButton"..i;

    -- Resize button if there isn't a scrollbar

    -- Display differently based on the saleStatus
    -- saleStatus "1" means that the item was sold
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality];
    local itemName = _G[buttonName.."Name"];
    local itemLevel = _G[buttonName.."Level"]
    local iconTexture = _G[buttonName.."ItemIconTexture"];
    iconTexture:SetTexture(texture);
    local itemCount = _G[buttonName.."ItemCount"];

    UpdatePrice(buttonName, auction)

    ResizeEntryAuctions(i, button, numBatchAuctions, totalAuctions)

    -- Normal item
    itemName:SetText(name);
    if (color) then
        itemName:SetVertexColor(color.r, color.g, color.b);
    end

    _G[buttonName.."RequestItem"]:Hide()

    _G[buttonName.."AuctionTypeText"]:SetText(ns.GetAuctionTypeDisplayString(auction.auctionType))

    UpdateDeliveryType(buttonName, auction)


    itemLevel:SetText(level);

    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    end

    if count > 1 and auction.itemID ~= ns.ITEM_ID_GOLD then
        itemCount:SetText(count)
        itemCount:Show()
    else
        itemCount:Hide()
    end
    button.itemCount = count
    button.itemID = auction.itemID
    button.itemIndex = index
    button.cancelPrice = 0
    button.auction = auction
    button.buyoutPrice = buyoutPrice
    button.isEnchantEntry = false

    -- Set highlight
    local selected = OFGetSelectedAuctionItem("owner")
    if ( selected and selected.id == auction.id ) then
        OFAuctionFrame.auction = auction
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

function OFAuctionFrameAuctions_Update()
    local auctions = ns.GetMyActiveAuctions(currentSortParams["owner"].params)
    local totalAuctions = #auctions
    local numBatchAuctions = min(totalAuctions + 2, OF_NUM_AUCTION_ITEMS_PER_PAGE)
	local offset = FauxScrollFrame_GetOffset(OFAuctionsScrollFrame)
	local index
	local isLastSlotEmpty
	local auction, button, itemName

	-- Update sort arrows
	OFSortButton_UpdateArrow(OFAuctionsQualitySort, "owner", "quality")
	OFSortButton_UpdateArrow(OFAuctionsLevelSort, "owner", "level")
    OFSortButton_UpdateArrow(OFAuctionsTypeSort, "owner", "type")
    OFSortButton_UpdateArrow(OFAuctionsDeliverySort, "owner", "delivery")
    OFSortButton_UpdateArrow(OFAuctionsBidSort, "owner", "bid")

	for i=1, OF_NUM_AUCTIONS_TO_DISPLAY do
		index = offset + i + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameAuctions.page)
        auction = auctions[index - 2]
        button = _G["OFAuctionsButton"..i];
        if (auction == nil) then
            button.auctionId = nil
        else
            button.auctionId = auction.id
        end

        local isItem = index == 1
        local isEnchantEntry = index == 2
		-- Show or hide auction buttons
        if isItem then
            auction = nil

            ns.TryExcept(
                function() UpdateItemEntry(index, i, offset, button, ns.ITEM_GOLD, numBatchAuctions, totalAuctions + 2, "owner") end,
                function(err)
                    button:Hide()
                    ns.DebugLog("OFAuctionFrameAuctions_Update UpdateItemEntry failed: ", err)
                end
            )
        elseif isEnchantEntry then
            auction = nil

            ns.TryExcept(
                function() UpdateEnchantAuctionEntry(index, i, offset, button, numBatchAuctions, totalAuctions + 2) end,
                function(err)
                    button:Hide()
                    ns.DebugLog("rendering auction item entry failed: ", err)
                end
            )

		elseif ( auction == nil or index > (numBatchAuctions + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameAuctions.page)) ) then
			button:Hide();
			-- If the last button is empty then set isLastSlotEmpty var
			isLastSlotEmpty = (i == OF_NUM_AUCTIONS_TO_DISPLAY);
		else
            itemName = ns.GetItemInfo(auction.itemID)
            if (itemName) then
                ns.TryExcept(
                    function() UpdateAuctionEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions + 2) end,
                    function(err) button:Hide(); ns.DebugLog("rendering auction entry failed: ", err) end
                )
            else
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFAuctionsButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                            function() UpdateAuctionEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalAuctions + 2) end,
                            function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred auction entry failed: ", err) end
                        )
                    end
                end)
            end
		end
	end
	-- If more than one page of auctions show the next and prev arrows when the scrollframe is scrolled all the way down
	if ( totalAuctions > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
		if ( isLastSlotEmpty ) then
			OFAuctionsSearchCountText:Show();
			OFAuctionsSearchCountText:SetFormattedText(SINGLE_PAGE_RESULTS_TEMPLATE, totalAuctions);
		else
			OFAuctionsSearchCountText:Hide();
		end

		-- Artifically inflate the number of results so the scrollbar scrolls one extra row
		numBatchAuctions = numBatchAuctions + 1;
	else
		OFAuctionsSearchCountText:Hide();
	end

    local selected = OFGetSelectedAuctionItem("owner")

	if (selected and ns.CanCancelAuction(selected)) then
        OFAuctionsCancelAuctionButton.auction = selected
		OFAuctionsCancelAuctionButton:Enable()
	else
        OFAuctionsCancelAuctionButton.auction = nil
		OFAuctionsCancelAuctionButton:Disable()
	end

	-- Update scrollFrame
	FauxScrollFrame_Update(OFAuctionsScrollFrame, numBatchAuctions, OF_NUM_AUCTIONS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT);
end

function GetEffectiveAuctionsScrollFrameOffset()
	return FauxScrollFrame_GetOffset(OFAuctionsScrollFrame)
end

function OFAuctionsButton_OnClick(button)
	assert(button)
    OFSetSelectedAuctionItem("owner", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameAuctions.cancelPrice = button.cancelPrice
	OFAuctionFrameAuctions_Update()
end


function OFAuctionSellItemButton_OnEvent(self, event, ...)
    if ( event == "NEW_AUCTION_UPDATE") then
        auctionSellItemInfo = pack(GetAuctionSellItemInfo())
        if ( name == OF_LAST_ITEM_AUCTIONED and count == OF_LAST_ITEM_COUNT ) then
            MoneyInputFrame_SetCopper(OFBuyoutPrice, OF_LAST_ITEM_BUYOUT)
        else
            local name, _, count, _, _, price, _, _, _, _ = OFGetAuctionSellItemInfo()
            MoneyInputFrame_SetCopper(OFBuyoutPrice, max(100, floor(price * 1.5)))
            if ( name ) then
                OF_LAST_ITEM_AUCTIONED = name
                OF_LAST_ITEM_COUNT = count
                OF_LAST_ITEM_BUYOUT = MoneyInputFrame_GetCopper(OFBuyoutPrice)
            end
        end
        UnlockCheckButton(OFAllowLoansCheckButton)
        OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
        OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
        OFUpdateAuctionSellItem()
	end
end

function OFAuctionSellItemButton_OnClick(self, button)
    if button == "RightButton" then
        DeselectAuctionItem()
    end
	ClickAuctionSellItemButton(self, button)
	OFAuctionsFrameAuctions_ValidateAuction()
end

function OFAuctionsFrameAuctions_ValidateAuction()
	OFAuctionsCreateAuctionButton:Disable()
	-- No item
    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
	if not name then
		return
	end

    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    if priceType == ns.PRICE_TYPE_MONEY then
        if ( MoneyInputFrame_GetCopper(OFBuyoutPrice) < 1 or MoneyInputFrame_GetCopper(OFBuyoutPrice) > OF_MAXIMUM_BID_PRICE) then
            return
        end
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        if OFTwitchRaidViewerAmount:GetNumber() < 1 then
            return
        end
    elseif priceType == ns.PRICE_TYPE_GUILD_POINTS then
        if OFTwitchRaidViewerAmount:GetNumber() < 1 then
            return
        end
    elseif priceType == ns.PRICE_TYPE_CUSTOM then
        local note = OFAuctionsNote:GetText()
        if (note == "" or note == OF_NOTE_PLACEHOLDER) and not duel and not deathRoll and not roleplay then
            return
        end
    end

    local isGold = itemID == ns.ITEM_ID_GOLD
    if isGold then
        if priceType == ns.PRICE_TYPE_MONEY then
            return
        end
    end

	OFAuctionsCreateAuctionButton:Enable()
end


function OFAuctionFrame_GetTimeLeftText(id)
	return _G["AUCTION_TIME_LEFT"..id]
end

function OFAuctionFrame_GetTimeLeftTooltipText(id)
	local text = _G["AUCTION_TIME_LEFT"..id.."_DETAIL"]
	return text
end

local function SetupUnitPriceTooltip(tooltip, type, auctionItem, excludeMissions)
    if not excludeMissions and auctionItem.auction and auctionItem.auction.deathRoll then
        GameTooltip_SetTitle(tooltip, L["Death Roll"])
        GameTooltip_AddNormalLine(tooltip, OF_DEATH_ROLL_TOOLTIP, true)
        tooltip:Show()
        return true
    end
    if not excludeMissions and auctionItem.auction and auctionItem.auction.duel then
        GameTooltip_SetTitle(tooltip, L["Duel (Normal)"])
        GameTooltip_AddNormalLine(tooltip, OF_DUEL_TOOLTIP, true)
        tooltip:Show()
        return true
    end
    if not excludeMissions and auctionItem.auction and auctionItem.auction.priceType == ns.PRICE_TYPE_CUSTOM then
        GameTooltip_SetTitle(tooltip, L["Custom Price"])
        GameTooltip_AddNormalLine(tooltip, auctionItem.auction.note, true)
        tooltip:Show()
        return true
    end

    if ( auctionItem and auctionItem.itemCount > 1 and auctionItem.buyoutPrice > 0 and auctionItem.itemID ~= ns.ITEM_ID_GOLD and (not auctionItem.auction or auctionItem.auction.priceType == ns.PRICE_TYPE_MONEY)) then
		-- If column is showing total price, then tooltip shows price per unit, and vice versa.

        local prefix
        local amount

        amount = auctionItem.buyoutPrice;
        prefix = AUCTION_TOOLTIP_BUYOUT_PREFIX
        amount = ceil(amount / auctionItem.itemCount)
        SetTooltipMoney(tooltip, amount, nil, prefix)

		-- This is necessary to update the extents of the tooltip
		tooltip:Show()

		return true
	end

    -- Show delivery tooltip if available
    if auctionItem.auction then
        GameTooltip_AddNormalLine(tooltip, ns.GetDeliveryTypeTooltip(auctionItem.auction), true)
        tooltip:Show()
        return true
    end

	return false
end

local function GetAuctionButton(buttonType, id)
	if ( buttonType == "owner" ) then
		return _G["OFAuctionsButton"..id];
	elseif ( buttonType == "bidder" ) then
		return _G["OFBidButton"..id];
	elseif ( buttonType == "list" ) then
		return _G["OFBrowseButton"..id];
	end
end

function OFAuctionBrowseFrame_CheckUnlockHighlight(self, selectedType, offset)
	local selected = OFGetSelectedAuctionItem(selectedType)
    local button = self.auction and self or self:GetParent()
    local auction = button.auction
	if ( not selected or not auction or selected.id ~= auction.id) then
		self:GetParent():UnlockHighlight()
	end
end

function OFAuctionPriceTooltipFrame_OnLoad(self)
    self:EnableMouse(true)
end

function OFAuctionPriceTooltipFrame_OnEnter(self)
	self:GetParent():LockHighlight();

	-- Unit price is only supported on the list tab, no need to pass in buttonType argument
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local button = GetAuctionButton("list", self:GetParent():GetID());
	local hasTooltip = SetupUnitPriceTooltip(GameTooltip, "list", button, false);
	if (not hasTooltip) then
		GameTooltip_Hide();
	end
	activeTooltipPriceTooltipFrame = self;
end

function OFAuctionPriceTooltipFrame_OnLeave(self)
	OFAuctionBrowseFrame_CheckUnlockHighlight(self, "list", FauxScrollFrame_GetOffset(OFBrowseScrollFrame));
	GameTooltip_Hide();
	activeTooltipPriceTooltipFrame = nil;
end

function OFAuctionFrameItem_OnEnter(self, type)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

    -- Add price per unit info
    local button = self:GetParent()
    if button.isEnchantEntry then
        GameTooltip_SetTitle(GameTooltip, L["Enchants"])
        GameTooltip_AddNormalLine(GameTooltip, L["Select the enchant you want to put up for auction"], true)
    elseif type == "owner" and button.itemID == ns.ITEM_ID_GOLD then
        GameTooltip_SetTitle(GameTooltip, L["Gold"])
        GameTooltip_AddNormalLine(GameTooltip, L["Select the amount of gold you want to put up for auction"], true)
    elseif ns.IsFakeItem(button.itemID) then
        local title, description = ns.GetFakeItemTooltip(button.itemID)
        GameTooltip_SetTitle(GameTooltip, title)
        GameTooltip_AddNormalLine(GameTooltip, description, true)
    elseif ns.IsSpellItem(button.itemID) then
        local spellID = ns.ItemIDToSpellID(button.itemID)
        if spellID then
            GameTooltip:SetHyperlink("spell:" .. spellID)
        end
    else
        GameTooltip:SetHyperlink("item:" .. button.itemID)
    end
    GameTooltip:Show()

    SetupUnitPriceTooltip(GameTooltip, type, button, true);
    if (type == "list") then
        activeTooltipAuctionFrameItem = self;
    end
    if button.itemID ~= ns.ITEM_ID_GOLD then
        GameTooltip_ShowCompareItem()
    end

    if (IsModifiedClick("DRESSUP")) then
        ShowInspectCursor();
    else
        ResetCursor();
    end
end

function OFAuctionFrameItem_OnClickModified(self, type, index, overrideID)
    local button = GetAuctionButton(type, overrideID or self:GetParent():GetID())
    local _, link = ns.GetItemInfo(button.itemID)
    if link then
        HandleModifiedItemClick(link)
    end
end

function OFAuctionFrameItem_OnLeave(self)
	GameTooltip_Hide()
	ResetCursor()
	activeTooltipAuctionFrameItem = nil
end


-- SortButton functions
function OFSortButton_UpdateArrow(button, type, sort)
	local primaryColumn, reversed = GetAuctionSortColumn(type);
	button.Arrow:SetShown(sort == primaryColumn);
	if (sort == primaryColumn) then
		if (reversed) then
			button.Arrow:SetTexCoord(0, 0.5625, 1, 0);
		else
			button.Arrow:SetTexCoord(0, 0.5625, 0, 1);
		end
	end
end

-- Function to close popups if another auction item is selected
function OFCloseAuctionStaticPopups()
	StaticPopup_Hide("OF_CANCEL_AUCTION_PENDING")
    StaticPopup_Hide("OF_BUY_AUCTION_DEATH_ROLL")
    StaticPopup_Hide("OF_BUY_AUCTION_DUEL")
    StaticPopup_Hide("OF_BUY_AUCTION_GOLD")
    StaticPopup_Hide("OF_MARK_AUCTION_COMPLETE")
    StaticPopup_Hide("OF_CANCEL_AUCTION_ACTIVE")
    StaticPopup_Hide("OF_FORGIVE_LOAN")
    StaticPopup_Hide("OF_DECLARE_BANKRUPTCY")
    StaticPopup_Hide("OF_FULFILL_AUCTION")
    StaticPopup_Hide("OF_SELECT_AUCTION_MONEY")

    ns.AuctionBuyConfirmPrompt:Hide()
    ns.AuctionWishlistConfirmPrompt:Hide()
end

function OFBidForgiveLoanButton_OnClick(self)
    if ns.IsSpellItem(OFAuctionFrame.auction.itemID) then
        StaticPopup_Show("OF_MARK_AUCTION_COMPLETE")
    elseif OFAuctionFrame.auction.owner == UnitName("player") then
        StaticPopup_Show("OF_FORGIVE_LOAN")
    else
        StaticPopup_Show("OF_DECLARE_BANKRUPTCY")
    end
    self:Disable()
end

function OFAuctionsCreateAuctionButton_OnClick()
    OF_LAST_ITEM_BUYOUT = MoneyInputFrame_GetCopper(OFBuyoutPrice)
    DropCursorMoney()

    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
    local note = OFAuctionsNote:GetText()
    if note == OF_NOTE_PLACEHOLDER then
        note = ""
    end

    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    local deliveryType = OFAuctionFrameAuctions.deliveryTypeIndex
    local buyoutPrice, raidAmount, points
    if priceType == ns.PRICE_TYPE_MONEY then
        buyoutPrice = GetBuyoutPrice()
        raidAmount = 0
        points = 0
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        buyoutPrice = 0
        raidAmount = OFTwitchRaidViewerAmount:GetNumber()
        points = 0
    elseif priceType == ns.PRICE_TYPE_GUILD_POINTS then
        buyoutPrice = 0
        raidAmount = 0
        points = OFTwitchRaidViewerAmount:GetNumber()
    else
        buyoutPrice = 0
        raidAmount = 0
        points = 0
    end


    local error, auctionCap, _
    auctionCap = ns.GetConfig().auctionCap
    if #ns.GetMyAuctions() >= auctionCap then
        error = string.format(L["You cannot have more than %d auctions"], auctionCap)
    else
        _, error = ns.AuctionHouseAPI:CreateAuction(itemID, buyoutPrice, count, allowLoans, priceType, deliveryType, ns.AUCTION_TYPE_SELL, roleplay, deathRoll, duel, raidAmount, points, note)
    end
    if error then
        UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        PlaySoundFile("sound/interface/error.ogg", "Dialog")
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
    end

    -- do these actions without playing the SFX connected to selecting and dropping the item in your bag
    local prev = GetCVar("Sound_EnableSFX")
    SetCVar("Sound_EnableSFX", 0)
    ns.TryFinally(
        function()
            OFAuctionsNote:SetText(OF_NOTE_PLACEHOLDER)
            ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
            auctionSellItemInfo = nil
            OFUpdateAuctionSellItem()
            OFAuctionFrameAuctions_Update()
            ClearCursor()
        end,
        function()
            SetCVar("Sound_EnableSFX", prev)
        end
    )
end

function OFReadOnlyEditBox_OnLoad(self, content)
    self:SetText(content)
    self:SetCursorPosition(0)
    self:SetScript("OnEscapePressed", function()
        self:ClearFocus()
    end)
    self:SetScript("OnEditFocusLost", function()
        self:SetText(content)
    end)
    self:SetScript("OnEditFocusGained", function()
        self:SetText(content)
        C_Timer:After(0.2, function()
            self:SetCursorPosition(0)
            self:HighlightText()
        end)
    end)

end

function OFRatingFrame_OnLoad(self)
    local starRating = ns.CreateStarRatingWidget({
        starSize = 6,
        panelHeight = 6,
        marginBetweenStarsX = 1,
        leftMargin = 2,
        labelFont = "GameFontNormalSmall",
    })
    self.ratingWidget = starRating
    starRating.frame:SetParent(self)
    starRating.frame:SetPoint("LEFT", self, "LEFT", -2, 0)
    starRating:SetRating(3.5)
    starRating.frame:Show()
end
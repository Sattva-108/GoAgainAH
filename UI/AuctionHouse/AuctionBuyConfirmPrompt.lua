local _, ns = ...

--------------------------------------------------------------------------------
-- Sample Ace3-based "Buy Auction" prompt
--------------------------------------------------------------------------------
local AceGUI = LibStub("AceGUI-3.0")
local AuctionHouse = ns.AuctionHouse

local AuctionBuyConfirmPrompt = AuctionHouse:NewModule("AuctionBuyConfirmPrompt", "AceEvent-3.0")
ns.AuctionBuyConfirmPrompt = AuctionBuyConfirmPrompt

-- Call this function from your addon when you need to show the Buy Auction window.
local function CreateBuyAuctionPrompt()
    -- Create the main frame
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle("Buy Auction")
    frame:SetLayout("Flow")
    frame.frame:SetResizable(false)
    frame:SetWidth(380)
    frame:SetHeight(450)

    local closeButton = CreateFrame("Button", "ExitButton", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7,7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    ----------------------------------------------------------------------------
    -- Seller Info Row
    ----------------------------------------------------------------------------
    local sellerGroup = AceGUI:Create("InlineGroup")
    sellerGroup:SetFullWidth(true)
    sellerGroup:SetLayout("List")
    sellerGroup:SetTitle("Seller")
    sellerGroup:SetHeight(80)
    frame:AddChild(sellerGroup)

    -- Seller name
    local sellerNameLabel = AceGUI:Create("Label")
    sellerNameLabel:SetText("PlayerName (TwitchName)")
    sellerNameLabel:SetFullWidth(true)
    sellerGroup:AddChild(sellerNameLabel)


    ----------------------------------------------------------------------------
    -- Tip Section
    ----------------------------------------------------------------------------
    local tipGroup = AceGUI:Create("InlineGroup")
    tipGroup:SetFullWidth(true)
    tipGroup:SetLayout("List")
    tipGroup:SetTitle("Add a tip?")
    tipGroup:SetHeight(240)
    frame:AddChild(tipGroup)

    local tipMoneyInputFrame = CreateFrame("FRAME", "BuyoutMoneyFrame", tipGroup.frame, "MoneyInputFrameTemplate")
    tipMoneyInputFrame:SetPoint("BOTTOM", tipGroup.frame, "BOTTOM", 10, 14)
    tipMoneyInputFrame:SetWidth(180)
    tipMoneyInputFrame:SetScale(1.5)

    local tipButtonHeight = 40
    -- 15% Button
    local button15 = AceGUI:Create("Button")
    button15:SetText("15%")
    button15:SetFullWidth(true)
    button15:SetHeight(tipButtonHeight)

    tipGroup:AddChild(button15)


    -- 20% Button
    local button20 = AceGUI:Create("Button")
    button20:SetText("20%")
    button20:SetFullWidth(true)
    button20:SetHeight(tipButtonHeight)

    tipGroup:AddChild(button20)

    -- 25% Button
    local button25 = AceGUI:Create("Button")
    button25:SetText("25%")
    button25:SetFullWidth(true)
    button25:SetHeight(tipButtonHeight)
    tipGroup:AddChild(button25)

    -- Divider section with "custom" text
    local dividerGroup = AceGUI:Create("SimpleGroup")
    dividerGroup:SetFullWidth(true)
    dividerGroup:SetLayout("Flow")
    dividerGroup:SetHeight(16)
    
    -- Left divider
    local leftDivider = AceGUI:Create("Label")
    leftDivider:SetImage("interface/mailframe/ui-mailframe-invoiceline.blp")
    leftDivider:SetImageSize(120, 16)
    leftDivider:SetWidth(120)
    leftDivider:SetHeight(16)
    dividerGroup:AddChild(leftDivider)
    
    -- Custom text in center
    local customText = AceGUI:Create("Label")
    customText:SetText("custom")
    customText:SetWidth(80)
    customText:SetHeight(16)
    customText:SetJustifyH("CENTER")
    dividerGroup:AddChild(customText)
    
    -- Right divider
    local rightDivider = AceGUI:Create("Label")
    rightDivider:SetImage("interface/mailframe/ui-mailframe-invoiceline.blp")
    rightDivider:SetImageSize(120, 16)
    rightDivider:SetWidth(120)
    rightDivider:SetHeight(16)
    dividerGroup:AddChild(rightDivider)
    
    tipGroup:AddChild(dividerGroup)

    local space = AceGUI:Create("InlineGroup")
    space:SetFullWidth(true)
    space:SetHeight(30)
    space.frame:SetAlpha(0)
    tipGroup:AddChild(space)

    ----------------------------------------------------------------------------
    -- Item Info Row
    ----------------------------------------------------------------------------
    local itemGroup = AceGUI:Create("InlineGroup")
    itemGroup:SetFullWidth(true)
    itemGroup:SetLayout("Flow")
    itemGroup:SetHeight(80)
    frame:AddChild(itemGroup)

    -- Left side container for icon and name
    local leftContainer = AceGUI:Create("SimpleGroup") 
    leftContainer:SetLayout("Flow")
    leftContainer:SetWidth(150)
    leftContainer:SetHeight(80)
    itemGroup:AddChild(leftContainer)

    -- Item Icon (placeholder icon: QuestionMark)
    local itemIcon = AceGUI:Create("Icon")
    itemIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
    itemIcon:SetImageSize(32, 32)
    itemIcon:SetWidth(40)
    
    -- Add count text in bottom right
    local countText = itemIcon.frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", -2, 2)
    countText:SetText("1")
    itemIcon.countText = countText -- Store reference for updating later
    
    leftContainer:AddChild(itemIcon)

    -- Item Name
    local itemNameLabel = AceGUI:Create("Label")
    itemNameLabel:SetText("|cffffffffVery long Item Name Here|r")
    itemNameLabel:SetWidth(100)
    leftContainer:AddChild(itemNameLabel)

    -- Right side container for buyout and tip
    local rightContainer = AceGUI:Create("SimpleGroup")
    rightContainer:SetLayout("List")
    rightContainer:SetWidth(100)
    rightContainer:SetHeight(100)
    itemGroup:AddChild(rightContainer)

    -- Buyout container
    local buyoutContainer = AceGUI:Create("SimpleGroup")
    buyoutContainer:SetLayout("Flow")
    buyoutContainer:SetFullWidth(true)
    buyoutContainer:SetHeight(40)
    rightContainer:AddChild(buyoutContainer)

    local buyoutLabel = AceGUI:Create("Label")
    buyoutLabel:SetText("Buyout")
    buyoutLabel:SetWidth(60)
    buyoutContainer:AddChild(buyoutLabel)

    local buyoutMoneyFrame = CreateFrame("Frame", "BuyoutMoneyFrame", buyoutContainer.frame, "MoneyFrameTemplate")
    MoneyFrame_SetType(buyoutMoneyFrame, "AUCTION");
    buyoutMoneyFrame:SetPoint("LEFT", buyoutLabel.frame, "RIGHT", 0, 0)
    buyoutMoneyFrame:SetScale(0.8)

    -- Tip container
    local tipContainer = AceGUI:Create("SimpleGroup")
    tipContainer:SetLayout("Flow")
    tipContainer:SetFullWidth(true)
    tipContainer:SetHeight(40)
    rightContainer:AddChild(tipContainer)

    local tipLabel = AceGUI:Create("Label")
    tipLabel:SetText("Tip")
    tipLabel:SetWidth(60)
    tipContainer:AddChild(tipLabel)

    local tipMoneyFrame = CreateFrame("Frame", "TipMoneyFrame", tipContainer.frame, "MoneyFrameTemplate")
    MoneyFrame_SetType(tipMoneyFrame, "AUCTION");
    tipMoneyFrame:SetPoint("LEFT", tipLabel.frame, "RIGHT", 0, 0)
    tipMoneyFrame:SetScale(0.8)

    ----------------------------------------------------------------------------
    -- Big Buyout Button
    ----------------------------------------------------------------------------
    local buyoutButton = AceGUI:Create("Button")
    -- You can include a money frame next to this text, or simply show it in the text

    buyoutButton:SetText("Buyout")
    buyoutButton:SetFullWidth(true)
    buyoutButton:SetHeight(40)
    frame:AddChild(buyoutButton)

    local prompt = {
        frame = frame,
        sellerNameLabel = sellerNameLabel,
        tipMoneyInputFrame = tipMoneyInputFrame,
        buyoutMoneyFrame = buyoutMoneyFrame,
        tipMoneyFrame = tipMoneyFrame,
        submitButton = buyoutButton,
        itemIcon = itemIcon,
        itemNameLabel = itemNameLabel,
        buyoutLabel = buyoutLabel,
        changingTipAmount = false,
    }

    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    end

    function prompt:SetSubmitButtonText(text)
        self.submitButton:SetText(text)
    end

    function prompt:SetTile(name)
        self.frame:SetTitle(name)
    end

    function prompt:SetSellerName(name)
        self.sellerNameLabel:SetText(name)
    end

    function prompt:SetTipAmount(amount)
        self.changingTipAmount = true
        MoneyFrame_Update(self.tipMoneyFrame, amount)
        MoneyInputFrame_SetCopper(self.tipMoneyInputFrame, amount)
        self.changingTipAmount = false
    end

    function prompt:SetPrice(amount)
        MoneyFrame_Update(self.buyoutMoneyFrame, amount)
    end

    function prompt:SetItem(itemID, quantity)
        ns.GetItemInfoAsync(itemID, function(...)
            local itemInfo = ns.ItemInfoToTable(...)
            self.itemNameLabel:SetText(itemInfo.name)
            self.itemIcon:SetImage(itemInfo.texture)
        end, quantity)

        if quantity > 1 and itemID ~= ns.ITEM_ID_GOLD then
            self.itemIcon.countText:SetText(quantity)
        else
            self.itemIcon.countText:SetText("")
        end
    end

    function prompt:OnCustomTipChanged(callback)
        MoneyInputFrame_SetOnValueChangedFunc(self.tipMoneyInputFrame, function()
            if not self.changingTipAmount then
                local money = MoneyInputFrame_GetCopper(self.tipMoneyInputFrame)
                callback(money)
            end
        end)
    end

    function prompt:OnPresetTipChanged(callback)
        button15:SetCallback("OnClick", function(widget)
            callback(0.15)
        end)
        button20:SetCallback("OnClick", function(widget)
            callback(0.20)
        end)
        button25:SetCallback("OnClick", function(widget)
            callback(0.25)
        end)
    end

    function prompt:TogglePriceType(priceType, raidAmount)
        local presetTips = priceType ~= ns.PRICE_TYPE_MONEY
        button15:SetDisabled(presetTips)
        button20:SetDisabled(presetTips)
        button25:SetDisabled(presetTips)
        if priceType == ns.PRICE_TYPE_TWITCH_RAID then
            self.buyoutLabel:SetWidth(130)
            self.buyoutLabel:SetText(string.format("Twitch Raid %d+", raidAmount))
            self.buyoutMoneyFrame:Hide()
        elseif priceType == ns.PRICE_TYPE_CUSTOM then
            self.buyoutLabel:SetText("")
            self.buyoutMoneyFrame:Hide()
        else
            self.buyoutLabel:SetWidth(60)
            self.buyoutLabel:SetText("Buyout")
            self.buyoutMoneyFrame:Show()
        end
    end

    function prompt:OnSubmit(callback)
        buyoutButton:SetCallback("OnClick", function(widget)
            callback()
        end)
    end

    function prompt:OnCancel(callback)
        closeButton:SetScript("OnClick", function()
            self.frame:Hide()
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
            callback()
        end)
    end

    return prompt
end

function AuctionBuyConfirmPrompt:Hide()
    if self.prompt then
        self.prompt:Hide()
    end
end

function AuctionBuyConfirmPrompt:Show(auction, withLoan, onSuccess, onError, onCancel)
    if not self.prompt then
        self.prompt = CreateBuyAuctionPrompt()
    end
    local title, submitButtonText
    if withLoan then
        title = "Buy Auction with Loan"
        submitButtonText = "Loan"
    else
        title = "Buy Auction"
        submitButtonText = "Buyout"
    end
    local tipAmount = 0
    local prompt = self.prompt
    self.prompt:SetTile(title)
    self.prompt:SetSubmitButtonText(submitButtonText)
    self.prompt:SetSellerName(ns.GetDisplayName(auction.owner))
    self.prompt:SetPrice(auction.price)
    self.prompt:SetTipAmount(0)
    self.prompt:SetItem(auction.itemID, auction.quantity)

    self.prompt:OnCustomTipChanged(function(money)
        self.prompt:SetTipAmount(money)
        tipAmount = money
    end)
    self.prompt:OnPresetTipChanged(function(percent)
        local buyout = auction.price
        local tip = math.floor(buyout * percent)
        tipAmount = tip
        self.prompt:SetTipAmount(tip)
    end)
    self.prompt:TogglePriceType(auction.priceType, auction.raidAmount)


    self.prompt:OnSubmit(function()
        if not withLoan and tipAmount + auction.price > GetMoney() then
            PlayVocalErrorSoundID(40)
            UIErrorsFrame:AddMessage(ERR_NOT_ENOUGH_MONEY, 1.0, 0.1, 0.1, 1.0)
            return
        end

        local res, err
        if withLoan then
             res, err = ns.AuctionHouseAPI:RequestBuyAuctionWithLoan(auction.id, tipAmount)
        else
            res, err = ns.AuctionHouseAPI:RequestBuyAuction(auction.id, tipAmount)
        end
        if res then
            if onSuccess then
                onSuccess()
            end
        else
            if onError then
                onError(err)
            end
        end
        prompt:Hide()
    end)
    self.prompt:OnCancel(function()
        if onCancel then
            onCancel()
        end
    end)
    self.prompt:Show()
end

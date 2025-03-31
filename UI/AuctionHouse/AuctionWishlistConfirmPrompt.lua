local _, ns = ...

local AceGUI = LibStub("AceGUI-3.0")
local AuctionHouse = ns.AuctionHouse

local AuctionWishlistConfirmPrompt = AuctionHouse:NewModule("AuctionWishlistConfirmPrompt", "AceEvent-3.0")
ns.AuctionWishlistConfirmPrompt = AuctionWishlistConfirmPrompt

local NOTES_PLACEHOLDER = OF_NOTE_PLACEHOLDER

local function CreateWishlistConfirmPrompt()
    -- Create the main frame
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle("Request Item")
    frame:SetLayout("Flow")
    frame.frame:SetResizable(false)
    frame:SetWidth(400)
    frame:SetHeight(430)

    local closeButton = CreateFrame("Button", "ExitButton", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7,7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    -------------------------------------------------------------------------------
    -- Main container that holds icon on the left and texts on the right
    -------------------------------------------------------------------------------
    local itemGroup = AceGUI:Create("InlineGroup") -- Changed from InlineGroup to SimpleGroup
    itemGroup:SetTitle("Item")
    itemGroup.noAutoHeight = true
    itemGroup:SetFullWidth(true)
    itemGroup:SetLayout("Flow") -- Changed to Flow layout to put icon and text side by side
    itemGroup:SetHeight(100) -- Set explicit height
    frame:AddChild(itemGroup)

    -- Item Icon (with fixed width so it won't expand)
    local itemIconGroup = AceGUI:Create("SimpleGroup")
    itemIconGroup:SetLayout("List")       -- one item per line
    itemIconGroup:SetWidth(45) -- Set explicit width for text area
    itemIconGroup:SetHeight(45)
    itemGroup:AddChild(itemIconGroup)

    local itemIcon = AceGUI:Create("Icon")
    itemIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
    itemIcon:SetImageSize(40, 40)
    itemIcon:SetWidth(45)  -- a bit larger than the image to give padding
    itemIcon:SetHeight(45)  -- a bit larger than the image to give padding
    itemIconGroup:AddChild(itemIcon)

    local space = AceGUI:Create("Label")
    space:SetText("         ")
    space:SetWidth(45)  -- a bit larger than the image to give padding
    space:SetHeight(45)  -- a bit larger than the image to give padding
    itemIconGroup:AddChild(space)

    -- Vertical group for the name (top) and the amount row (below)
    local verticalGroup = AceGUI:Create("SimpleGroup")
    verticalGroup:SetLayout("List")       -- one item per line
    verticalGroup:SetWidth(280) -- Set explicit width for text area
    verticalGroup:SetHeight(80)
    itemGroup:AddChild(verticalGroup)


    local space = AceGUI:Create("Label")
    space:SetText("                                  ")
    space:SetHeight(10)
    verticalGroup:AddChild(space)
    ----------------------------------------------------------------------------
    -- Item Name (top label)
    ----------------------------------------------------------------------------
    local itemNameLabel = AceGUI:Create("Label")
    itemNameLabel:SetText("Very long Item Name Here")
    itemNameLabel.label:SetFontObject(GameFontNormal)
    itemNameLabel:SetHeight(30)
    verticalGroup:AddChild(itemNameLabel)

    ----------------------------------------------------------------------------
    -- Amount row (labels + input on same horizontal line)
    ----------------------------------------------------------------------------
    local amountContainer = AceGUI:Create("SimpleGroup")
    amountContainer:SetLayout("Flow")   -- place child widgets side by side
    amountContainer:SetHeight(50)
    verticalGroup:AddChild(amountContainer)

    -- Amount Label
    local amountLabel = AceGUI:Create("Label")
    amountLabel:SetText("Amount")
    amountLabel:SetWidth(55)
    amountLabel.label:SetFontObject(GameFontNormal)
    amountLabel.label:SetTextColor(1, 0.82, 0)
    amountLabel:SetHeight(20)
    -- If you want a fixed width for the label: amountLabel:SetWidth(50)
    amountContainer:AddChild(amountLabel)

    -- Amount Input
    local amountInput = AceGUI:Create("EditBox")
    amountInput:SetWidth(70)
    amountInput:SetHeight(20)
    amountInput:SetMaxLetters(4)
    amountInput:DisableButton(true)
    amountInput.editbox:SetNumeric(true)
    amountContainer:AddChild(amountInput)

    -- Gold Amount input
    local goldAmountInputMoneyFrame = CreateFrame("Frame", "RequestGoldAmountInputMoneyFrame", amountLabel.frame, "MoneyInputFrameTemplate")
    goldAmountInputMoneyFrame:SetPoint("LEFT", amountLabel.frame, "RIGHT", 15, 0)

    ----------------------------------------------------------------------------
    -- Reward Section
    ----------------------------------------------------------------------------
    local rewardGroup = AceGUI:Create("InlineGroup")
    rewardGroup:SetTitle("Reward")
    rewardGroup:SetLayout("Flow")
    rewardGroup:SetFullWidth(true)
    frame:AddChild(rewardGroup)




    -- Price Type Dropdown
    local priceTypeLabel = AceGUI:Create("Label")
    priceTypeLabel:SetText("Type")
    priceTypeLabel:SetWidth(50)
    priceTypeLabel.label:SetFontObject(GameFontNormalSmall)
    priceTypeLabel.label:SetTextColor(1, 0.82, 0)
    rewardGroup:AddChild(priceTypeLabel)


    local priceTypeDropdown = AceGUI:Create("Dropdown")
    priceTypeDropdown:SetList({
        ["Gold"] = "Gold",
        ["TwitchRaid"] = "Twitch Raid",
        ["Other"] = "Other",
    })
    priceTypeDropdown:SetValue("Gold")
    priceTypeDropdown:SetWidth(120)

    rewardGroup:AddChild(priceTypeDropdown)

    local priceInputMoneyFrame = CreateFrame("Frame", "RequestPriceInputMoneyFrame", priceTypeDropdown.frame, "MoneyInputFrameTemplate")
    priceInputMoneyFrame:SetPoint("LEFT", priceTypeDropdown.frame, "RIGHT", 15, 0)

    local twitchRaidLabel = AceGUI:Create("Label")
    twitchRaidLabel:SetText(" Min Viewers")
    twitchRaidLabel:SetWidth(85)
    twitchRaidLabel.label:SetFontObject(GameFontNormal)
    twitchRaidLabel.label:Hide()
    rewardGroup:AddChild(twitchRaidLabel)

    local raidAmountInput = AceGUI:Create("EditBox")
    raidAmountInput:SetWidth(70)
    raidAmountInput:SetHeight(20)
    raidAmountInput:SetMaxLetters(6)
    raidAmountInput:DisableButton(true)
    raidAmountInput.editbox:SetNumeric(true)
    raidAmountInput:SetText("200")
    raidAmountInput.editbox:Hide()
    rewardGroup:AddChild(raidAmountInput)

    local space = AceGUI:Create("Label")
    space:SetText(" ")
    space:SetHeight(1)
    space:SetFullWidth(true)
    rewardGroup:AddChild(space)

    local deliveryTypeLabel = AceGUI:Create("Label")
    deliveryTypeLabel:SetText("Delivery")
    deliveryTypeLabel:SetWidth(50)
    deliveryTypeLabel.label:SetFontObject(GameFontNormalSmall)
    deliveryTypeLabel.label:SetTextColor(1, 0.82, 0)
    rewardGroup:AddChild(deliveryTypeLabel)


    local deliveryTypeDropdown = AceGUI:Create("Dropdown")
    deliveryTypeDropdown:SetList({
        ["Any"] = "Any",
        ["Mail"] = "Mail",
        ["Trade"] = "Trade"
    })
    deliveryTypeDropdown:SetValue("Any")
    deliveryTypeDropdown:SetWidth(120)

    rewardGroup:AddChild(deliveryTypeDropdown)

    local space = AceGUI:Create("Label")
    space:SetText(" ")
    space:SetHeight(1)
    space:SetFullWidth(true)
    rewardGroup:AddChild(space)

    local roleplayCheck = AceGUI:Create("CheckBox")
    roleplayCheck:SetLabel("Roleplay")
    roleplayCheck:SetWidth(100)
    roleplayCheck.frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(roleplayCheck.frame, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, "Roleplay")
        GameTooltip_AddNormalLine(GameTooltip, OF_ROLEPLAY_TOOLTIP, true)
        GameTooltip:Show()
    end)

    roleplayCheck.frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rewardGroup:AddChild(roleplayCheck)

    local deathRollCheck = AceGUI:Create("CheckBox")
    deathRollCheck:SetLabel("Death Roll")
    deathRollCheck:SetWidth(100)
    deathRollCheck.frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(deathRollCheck.frame, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, "Death Roll");
        GameTooltip_AddNormalLine(GameTooltip, OF_DEATH_ROLL_TOOLTIP, true)
        GameTooltip:Show()
    end)
    deathRollCheck.frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local duelCheck = AceGUI:Create("CheckBox")
    duelCheck:SetLabel("Duel (Normal)")
    duelCheck:SetWidth(120)
    duelCheck.frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(deathRollCheck.frame, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, "Duel (Normal)");
        GameTooltip_AddNormalLine(GameTooltip, OF_DUEL_TOOLTIP, true)
        GameTooltip:Show()
    end)
    duelCheck.frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local onPriceTypeChanged = function(value)
        if value == "Gold" then
            priceInputMoneyFrame:Show()
            twitchRaidLabel.label:Hide()
            raidAmountInput.editbox:Hide()
        elseif value == "TwitchRaid" then
            priceInputMoneyFrame:Hide()
            twitchRaidLabel.label:Show()
            raidAmountInput.editbox:Show()
        else
            priceInputMoneyFrame:Hide()
            twitchRaidLabel.label:Hide()
            raidAmountInput.editbox:Hide()
        end
    end
    local onMissionChanged = function (deathRoll, duel)
        if deathRoll or duel then
            roleplayCheck:SetValue(false)
            roleplayCheck:SetDisabled(true)
            local newPriceType = "Gold"
            if not priceTypeDropdown.list[newPriceType] then
                newPriceType = "Other"
            end
            priceTypeDropdown:SetValue(newPriceType)
            onPriceTypeChanged(newPriceType)
            priceTypeDropdown:SetDisabled(true)
            deliveryTypeDropdown:SetValue("Trade")
            deliveryTypeDropdown:SetDisabled(true)
        else
            roleplayCheck:SetDisabled(false)
            priceTypeDropdown:SetDisabled(false)
            deliveryTypeDropdown:SetDisabled(false)
        end
        if deathRoll then
            duelCheck:SetValue(false)
            duelCheck:SetDisabled(true)
        elseif duel then
            deathRollCheck:SetValue(false)
            deathRollCheck:SetDisabled(true)
        else
            duelCheck:SetDisabled(false)
            deathRollCheck:SetDisabled(false)
        end
    end
    deathRollCheck:SetCallback("OnValueChanged", function(widget, event, value)
        onMissionChanged(value, false)
    end)
    duelCheck:SetCallback("OnValueChanged", function(widget, event, value)
        onMissionChanged(false, value)
    end)
    rewardGroup:AddChild(deathRollCheck)
    rewardGroup:AddChild(duelCheck)

    -- Notes Section
    local notesBox = AceGUI:Create("MultiLineEditBox")
    notesBox:SetLabel("Notes")
    notesBox:SetMaxLetters(100)
    notesBox:SetFullWidth(true)
    notesBox:SetHeight(60)
    notesBox.editBox:SetText(NOTES_PLACEHOLDER)
    notesBox.editBox:SetScript("OnEditFocusGained", function(self)
        if notesBox:GetText() == NOTES_PLACEHOLDER then
            notesBox:SetText("")
        end
    end)
    notesBox.editBox:SetScript("OnEditFocusLost", function(self)
        if notesBox:GetText() == "" then
            notesBox:SetText(NOTES_PLACEHOLDER)
        end
    end)
    notesBox:DisableButton(true)
    rewardGroup:AddChild(notesBox)


    ----------------------------------------------------------------------------
    -- Big Buyout Button
    ----------------------------------------------------------------------------
    local buyoutButton = AceGUI:Create("Button")
    -- You can include a money frame next to this text, or simply show it in the text

    buyoutButton:SetText("Create Request")
    buyoutButton:SetFullWidth(250)
    buyoutButton:SetHeight(40)
    buyoutButton.frame:SetPoint("CENTER", frame.frame, "CENTER", 0, 0)
    frame:AddChild(buyoutButton)

    local prompt = {
        frame = frame,
        submitButton = buyoutButton,
        itemIcon = itemIcon,
        itemNameLabel = itemNameLabel,
        amountInput = amountInput,
        goldAmountInputMoneyFrame = goldAmountInputMoneyFrame,
        priceTypeDropdown = priceTypeDropdown,
        deliveryTypeDropdown = deliveryTypeDropdown,
        priceInputMoneyFrame = priceInputMoneyFrame,
        raidAmountInput = raidAmountInput,
        roleplayCheck = roleplayCheck,
        deathRollCheck = deathRollCheck,
        duelCheck = duelCheck,
        notesBox = notesBox
    }

    priceTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        onPriceTypeChanged(value)
    end)

    function prompt:Reset()
        self.amountInput:SetText(1)
        self.priceTypeDropdown:SetValue("Gold")
        self.priceInputMoneyFrame:Show()
        self.raidAmountInput:SetText("200")
        self.raidAmountInput.editbox:Hide()
        self.deliveryTypeDropdown:SetValue("Any")
        self.roleplayCheck:SetValue(false)
        self.deathRollCheck:SetValue(false)
        self.duelCheck:SetValue(false)
        self.notesBox.editBox:SetText(NOTES_PLACEHOLDER)

        onPriceTypeChanged("Gold")
        self.deathRollCheck:SetValue(false)
        onMissionChanged(false, false)
    end

    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    end

    function prompt:SetItem(itemID, quantity)
        ns.GetItemInfoAsync(itemID, function(...)
            local itemInfo = ns.ItemInfoToTable(...)
            local isGold = itemID == ns.ITEM_ID_GOLD
            local color = ITEM_QUALITY_COLORS[itemInfo.quality] or { r = 255, g = 255, b = 255 };
            self.isGold = isGold
            self.itemNameLabel:SetText(itemInfo.name)
            self.itemNameLabel.label:SetTextColor(color.r, color.g, color.b)
            self.itemIcon:SetImage(itemInfo.texture)

            if itemInfo.itemStackCount > 1 then
                self.amountInput:SetText(itemInfo.itemStackCount)
                self.amountInput:SetDisabled(false)
            else
                self.amountInput:SetText(1)
                self.amountInput:SetDisabled(true)
            end

            -- Setup tooltip for the item icon
            self.itemIcon:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
                if ns.IsFakeItem(itemID) then
                    local title, description = ns.GetFakeItemTooltip(itemID)
                    GameTooltip_SetTitle(GameTooltip, title)
                    GameTooltip_AddNormalLine(GameTooltip, description, true)
                elseif ns.IsSpellItem(itemID) then
                    GameTooltip:SetSpellByID(ns.ItemIDToSpellID(itemID))
                else
                    GameTooltip:SetItemByID(itemID)
                end
                GameTooltip:Show()
            end)
            self.itemIcon:SetCallback("OnLeave", function()
                GameTooltip:Hide()
            end)

            self.amountInput:SetCallback("OnTextChanged", function(widget, event, text)
                local value = tonumber(text)
                if value and value > itemInfo.itemStackCount then
                    widget:SetText(itemInfo.itemStackCount)
                end
            end)

            if isGold then
                self.priceTypeDropdown:SetList({
                    ["TwitchRaid"] = "Twitch Raid",
                    ["Other"] = "Other",
                })
                self.priceTypeDropdown:SetValue("Other")
                MoneyInputFrame_SetCopper(self.priceInputMoneyFrame, 0)
                self.priceInputMoneyFrame:Hide()
                self.goldAmountInputMoneyFrame:Show()
                self.amountInput.editbox:Hide()
            else
                self.priceTypeDropdown:SetList({
                    ["Gold"] = "Gold",
                    ["TwitchRaid"] = "Twitch Raid",
                    ["Other"] = "Other",
                })
                self.priceTypeDropdown:SetValue("Gold")
                self.priceInputMoneyFrame:Show()
                MoneyInputFrame_SetCopper(self.priceInputMoneyFrame, itemInfo.itemSellPrice * itemInfo.itemStackCount)
                self.goldAmountInputMoneyFrame:Hide()
                self.amountInput.editbox:Show()
            end

            if ns.IsSpellItem(itemID) then
                self.deliveryTypeDropdown:SetValue("Trade")
                self.deliveryTypeDropdown:SetDisabled(true)
            else
                self.deliveryTypeDropdown:SetValue("Any")
                self.deliveryTypeDropdown:SetDisabled(false)
            end
        end, quantity)
    end

    function prompt:OnSubmit(callback)
        buyoutButton:SetCallback("OnClick", function(widget)
            local quantity
            if self.isGold then
                quantity = MoneyInputFrame_GetCopper(self.goldAmountInputMoneyFrame)
            else
                quantity = self.amountInput.editbox:GetNumber()
            end
            callback(
                quantity,
                self.priceTypeDropdown:GetValue(),
                MoneyInputFrame_GetCopper(self.priceInputMoneyFrame),
                self.deliveryTypeDropdown:GetValue(),
                self.raidAmountInput.editbox:GetNumber(),
                self.roleplayCheck:GetValue(),
                self.deathRollCheck:GetValue(),
                self.duelCheck:GetValue(),
                self.notesBox.editBox:GetText()
            )
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

function AuctionWishlistConfirmPrompt:Hide()
    if self.prompt then
        self.prompt:Hide()
    end
end

function AuctionWishlistConfirmPrompt:Show(itemID, onSuccess, onError, onCancel)
    if not self.prompt then
        self.prompt = CreateWishlistConfirmPrompt()
    end
    self.prompt:Reset()
    self.prompt:SetItem(itemID)

    self.prompt:OnSubmit(function(itemAmount, priceType, price, deliveryType, raidAmount, roleplay, deathRoll, duel, notes)
        if priceType == "Gold" then
            priceType = ns.PRICE_TYPE_MONEY
            raidAmount = 0
        elseif priceType == "TwitchRaid" then
            priceType = ns.PRICE_TYPE_TWITCH_RAID
            price = 0
        else
            priceType = ns.PRICE_TYPE_CUSTOM
            price = 0
            raidAmount = 0
        end

        if deliveryType == "Mail" then
            deliveryType = ns.DELIVERY_TYPE_MAIL
        elseif deliveryType == "Trade" then
            deliveryType = ns.DELIVERY_TYPE_TRADE
        else
            deliveryType = ns.DELIVERY_TYPE_ANY
        end



        if notes == NOTES_PLACEHOLDER then
            notes = ""
        end
        if priceType == ns.PRICE_TYPE_CUSTOM and notes == "" and not deathRoll and not duel and not roleplay then
            UIErrorsFrame:AddMessage("Leave a note for the custom price", 1.0, 0.1, 0.1, 1.0)
            PlaySoundFile("sound/interface/error.ogg", "Dialog")
            return
        end

        local res, err = ns.AuctionHouseAPI:CreateAuction(
            itemID,
            price,
            itemAmount,
            false, -- allow Loan
            priceType,
            deliveryType,
            ns.AUCTION_TYPE_BUY,
            roleplay,
            deathRoll,
            duel,
            raidAmount,
            notes
        )
        if res then
            if onSuccess then
                onSuccess()
            end
        else
            if onError then
                onError(err)
            end
        end
        self.prompt:Hide()
    end)
    self.prompt:OnCancel(function()
        if onCancel then
            onCancel()
        end
    end)
    self.prompt:Show()
end

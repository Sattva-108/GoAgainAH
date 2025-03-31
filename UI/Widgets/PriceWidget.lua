local addonName, ns = ...

local MAX_PRICE = (9999 * 100 * 100) + (99 * 100) + 99
local MONEY_FRAME_HEIGHT = 15

--------------------------------------------------------------------------------
-- CreateMoneyFrame
-- A helper function that creates a money display (gold/silver/copper) and
-- returns a frame with .SetMoney(copper) method
--------------------------------------------------------------------------------
local function CreateMoneyFrame(parent, rightPad)
    local root = CreateFrame("Frame", parent:GetName().."MoneyRoot", parent)

    local moneyFrame = CreateFrame("Frame", parent:GetName().."MoneyFrame", root)
    moneyFrame:SetPoint("RIGHT", root, "RIGHT", rightPad or -20, 0)

    -- Create and store references to all text elements
    root.goldText = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    root.silverText = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    root.copperText = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    -- white font
    root.goldText:SetTextColor(1, 1, 1)
    root.silverText:SetTextColor(1, 1, 1)
    root.copperText:SetTextColor(1, 1, 1)

    -- Create icons
    local goldIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    goldIcon:SetSize(11, 11)

    local silverIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    silverIcon:SetSize(11, 11)

    local copperIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    copperIcon:SetSize(11, 11)

    -- Decide spacing
    local symbolSpacing = 0  -- space between the text and its icon
    local groupSpacing = 1   -- space between gold group, silver group, etc.

    -- Anchor gold text & icon first
    root.goldText:SetPoint("BOTTOMLEFT", moneyFrame, "BOTTOMLEFT", 0, 0)
    goldIcon:SetPoint("LEFT", root.goldText, "RIGHT", symbolSpacing, 0)

    -- Anchor silver text & icon
    root.silverText:SetPoint("BOTTOMLEFT", goldIcon, "BOTTOMRIGHT", groupSpacing, 0)
    silverIcon:SetPoint("LEFT", root.silverText, "RIGHT", symbolSpacing, 0)

    -- Anchor copper text & icon
    root.copperText:SetPoint("BOTTOMLEFT", silverIcon, "BOTTOMRIGHT", groupSpacing, 0)
    copperIcon:SetPoint("LEFT", root.copperText, "RIGHT", symbolSpacing, 0)


    -- Add update method to the frame
    function root:SetMoney(copper)
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        local copperRemaining = copper % 100

        self.goldText:SetText(gold)
        self.silverText:SetText(silver)
        self.copperText:SetText(copperRemaining)
    end

    -- Initial update
    root:SetMoney(MAX_PRICE)

    ----------------------------------------------------------------------------
    -- Dynamically size the parent "moneyFrame" so text does not clip the icons.
    -- We measure each text’s width plus the icons and spacing, then set the frame.
    ----------------------------------------------------------------------------

    -- Force the FontStrings to update their widths so GetStringWidth is accurate.
    root.goldText:SetWidth(root.goldText:GetStringWidth())
    root.silverText:SetWidth(root.silverText:GetStringWidth() + 1)
    root.copperText:SetWidth(root.copperText:GetStringWidth() + 1)

    -- Set fixed size based on maximum possible values
    moneyFrame:SetSize(100, MONEY_FRAME_HEIGHT) -- Use a fixed size that can accommodate all values
    root:SetSize(100, MONEY_FRAME_HEIGHT) -- Use a fixed size that can accommodate all values

    return root
end

--------------------------------------------------------------------------------
-- CreateTextAndPriceWidget
-- Creates a small frame with a text label, optional "death roll" icon, and money
--------------------------------------------------------------------------------
local function CreateTextAndPriceWidget(parent, rightPad)
    -- Create label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText("Deathroll")
    label:SetJustifyH("RIGHT")
    label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

    -- Deathroll icon
    local deathRollIcon = parent:CreateTexture(nil, "ARTWORK")
    deathRollIcon:SetTexture("Interface\\Addons\\" .. addonName .. "\\Media\\icons\\Icn_DeathRoll")
    deathRollIcon:SetSize(12, 12)
    -- Position it to the left of the label
    deathRollIcon:SetPoint("RIGHT", label, "LEFT", -4, 0)

    -- Money frame anchored to the right edge
    local moneyFrame = CreateMoneyFrame(parent, 4 + rightPad)
    moneyFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4 + rightPad, 0)

    ---------------------------------------------------------------------------
    -- Return a table that represents the widget, with an UpdateView method
    ---------------------------------------------------------------------------
    local widget = {
        label = label,
        moneyFrame = moneyFrame,
        deathRollIcon = deathRollIcon,
    }

    function widget:Show()
        label:Show()
        moneyFrame:Show()
        deathRollIcon:Show()
    end

    function widget:Hide()
        label:Hide()
        moneyFrame:Hide()
        deathRollIcon:Hide()
    end

    function widget:UpdateView(config)
        local text = config.text or ""
        local color = config.color or {r = 1, g = 1, b = 1}
        local showIcon = (config.renderDeathRollIcon == true or config.renderDuelIcon == true)

        if config.renderDeathRollIcon then
            self.deathRollIcon:SetTexture("Interface\\Addons\\" .. addonName .. "\\Media\\icons\\Icn_DeathRoll")
        elseif config.renderDuelIcon then
            self.deathRollIcon:SetTexture("Interface\\Addons\\" .. addonName .. "\\Media\\icons\\Icn_Duel")
        end
        self.deathRollIcon:SetShown(showIcon)

        self.label:SetText(text)
        self.label:SetTextColor(color.r, color.g, color.b)

        if config.money then
            self.moneyFrame:SetMoney(config.money)
            self.moneyFrame:Show()
        else
            self.moneyFrame:SetMoney(0)
            self.moneyFrame:Hide()
        end
    end

    return widget
end

--------------------------------------------------------------------------------
-- CreatePriceWidget
-- Creates a frame containing:
--  - A price label and money frame
--  - A tip label and money frame
--  - An embedded text-and-price widget (for special states like "Deathroll")
--------------------------------------------------------------------------------
ns.CreatePriceWidget = function(parent, config)
    local rightPad = (config and config.rightPad) or 0
    local topPad = (config and config.topPad) or 0

    local frame = CreateFrame("Frame", "PriceWidget", parent)
    frame:SetSize(config and config.width or 152, config and config.height or 30)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -2)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 2)

    ---------------------------------------------------------------------------
    -- Price row
    ---------------------------------------------------------------------------
    local priceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceLabel:SetText("Price")
    priceLabel:SetTextColor(0.5, 0.5, 0.5)
    priceLabel:SetJustifyH("RIGHT")
    priceLabel:SetHeight(MONEY_FRAME_HEIGHT)

    local priceMoneyFrame = CreateMoneyFrame(frame, rightPad)

    -- Anchor the money frame to the top-right with some top padding
    priceMoneyFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightPad, -topPad + 2)
    -- Anchor the label 16px to the left of the money frame
    priceLabel:SetPoint("RIGHT", priceMoneyFrame, "LEFT", -2, -2)

    ---------------------------------------------------------------------------
    -- Tip row
    ---------------------------------------------------------------------------
    local tipLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tipLabel:SetText("Tip (0%)")
    tipLabel:SetTextColor(0.5, 0.5, 0.5)
    tipLabel:SetJustifyH("RIGHT")
    tipLabel:SetHeight(MONEY_FRAME_HEIGHT)

    local tipMoneyFrame = CreateMoneyFrame(frame, rightPad)

    -- Anchor the tip money frame below the price money frame
    tipMoneyFrame:SetPoint("TOPRIGHT", priceMoneyFrame, "BOTTOMRIGHT", 0, 2)
    -- Anchor the tip label 16px to the left of the tip money frame
    tipLabel:SetPoint("RIGHT", tipMoneyFrame, "LEFT", -2, -2)

    ---------------------------------------------------------------------------
    -- Text + price widget (for special states like "Deathroll", "TwitchRaid" etc.)
    ---------------------------------------------------------------------------
    local textAndPriceWidget = CreateTextAndPriceWidget(frame, rightPad)

    -- Adjust this section to match the same “vertical” anchoring style
    -- used for priceMoneyFrame and tipMoneyFrame elsewhere in the file:

    -- Clear existing points
    textAndPriceWidget.label:ClearAllPoints()
    textAndPriceWidget.moneyFrame:ClearAllPoints()

    -- Position label at the top (where priceMoneyFrame would be)
    textAndPriceWidget.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -topPad - 2)
    -- Position moneyFrame below the label (where tipMoneyFrame would be)
    textAndPriceWidget.moneyFrame:SetPoint("TOPRIGHT", textAndPriceWidget.label, "BOTTOMRIGHT", 0, 0)

    ---------------------------------------------------------------------------
    -- Build a small "widget" table with methods
    ---------------------------------------------------------------------------
    local widget = {
        frame = frame,

        priceLabel = priceLabel,
        priceMoneyFrame = priceMoneyFrame,

        tipLabel = tipLabel,
        tipMoneyFrame = tipMoneyFrame,

        textAndPriceWidget = textAndPriceWidget,
    }

    function widget:Show()
        self.frame:Show()
    end

    function widget:Hide()
        self.frame:Hide()
    end

    -- Mimics the logic from the existing code to toggle between normal price/tip
    -- or special states
    function widget:UpdateView(auction)
        -- Hide both the standard price+tip rows and the special text+price widget
        self.priceLabel:Hide()
        self.priceMoneyFrame:Hide()
        self.tipLabel:Hide()
        self.tipMoneyFrame:Hide()
        self.textAndPriceWidget.Hide()

        local money = (auction.price or 0) + (auction.tip or 0)
        if auction.itemID == ns.ITEM_ID_GOLD then
            money = nil -- hide the money frame
        end

        if auction.priceType == ns.PRICE_TYPE_TWITCH_RAID then
            self.textAndPriceWidget.Show()
            self.textAndPriceWidget:UpdateView({
                text = string.format("Twitch Raid %d+", auction.raidAmount or 0),
                money = money,
                renderDeathRollIcon = false,
            })

        elseif auction.deathRoll then
            self.textAndPriceWidget.Show()
            self.textAndPriceWidget:UpdateView({
                text = "Deathroll",
                renderDeathRollIcon = true,
                money = money,
            })
        elseif auction.duel then
            self.textAndPriceWidget.Show()
            self.textAndPriceWidget:UpdateView({
                text = "Duel (Normal)",
                renderDuelIcon = true,
                money = money,
            })

        elseif auction.itemID == ns.ITEM_ID_GOLD then
            self.textAndPriceWidget.Show()
            self.textAndPriceWidget:UpdateView({
                text = auction.roleplay and "Roleplay" or "",
                money = nil,
            })

        elseif auction.loanResult then
            local text = "loan"
            local color = {r = 1, g = 1, b = 1} -- default white
            if auction.loanResult == ns.LOAN_RESULT_BANKRUPTCY then
                text = "Declared Bankruptcy"
                color = {r = 1, g = 0.1, b = 0.1} -- red
            elseif auction.loanResult == ns.LOAN_RESULT_PAID then
                text = "Loan paid"
                color = {r = 0.1, g = 1, b = 0.1} -- green
            end

            self.textAndPriceWidget:Show()
            self.textAndPriceWidget:UpdateView({
                text = text,
                color = color,
                money = money,
            })

        else
            -- Default: show standard price + optional tip
            self.priceLabel:Show()
            self.priceMoneyFrame:Show()

            if auction.tip and auction.tip > 0 then
                self.tipLabel:Show()
                self.tipMoneyFrame:Show()

                self.tipMoneyFrame:SetMoney(auction.tip or 0)
                local tipPercentage = (auction.price > 0)
                    and math.floor((auction.tip or 0) / auction.price * 100)
                     or 0
                self.tipLabel:SetText(string.format("Tip (%d%%)", tipPercentage))
            end

            self.priceMoneyFrame:SetMoney(auction.price or 0)
        end
    end

    return widget
end

-- must make it global for the AuctionUI
CreatePriceWidget = ns.CreatePriceWidget
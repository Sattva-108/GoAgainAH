local addonName, ns = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local reviewPrompt

-- Placeholder icons used temporarily for each emotion
local REACTION_ICONS = {
    [1] = "Interface\\AddOns\\GoAgainAH\\Media\\smiley_64x64.tga",       -- 😂 Funny
    [2] = "Interface\\AddOns\\GoAgainAH\\Media\\eyes_64x64.tga",      -- 🕯️ Sad
    [3] = "Interface\\AddOns\\GoAgainAH\\Media\\clown_64x64.tga",       -- ♿ Boring
    [4] = "Interface\\AddOns\\GoAgainAH\\Media\\fire_64x64.tga",        -- 💪 Heroic
}

local function CreateReactionWidget(config)
    local group = AceGUI:Create("MinimalFrame")
    group:SetHeight(config.height or 42)
    group:SetWidth(300)
    group:SetLayout("Flow")
    group.selectedIndex = 0
    group.buttons = {}
    group:Show()

    local function updateHighlight()
        for i, btn in ipairs(group.buttons) do
            if i == group.selectedIndex then
                btn.border:Show()
            else
                btn.border:Hide()
            end
        end
    end

    function group:SetSelected(index, silent)
        self.selectedIndex = index
        updateHighlight()
        if not silent and config.onSelect then
            config.onSelect(index)
        end
    end

    function group:GetSelected()
        return self.selectedIndex
    end

    local ICON_SIZE = config.iconSize or 40
    local iconWrapper = CreateFrame("Frame", nil, group.frame)
    iconWrapper:SetSize((ICON_SIZE + 16) * 4, ICON_SIZE)
    iconWrapper:SetPoint("TOP", group.frame, "TOP", 0, -8)
    group.iconWrapper = iconWrapper

    for i = 1, 4 do
        local frame = CreateFrame("Button", nil, iconWrapper)
        frame:SetSize(ICON_SIZE, ICON_SIZE)

        -- Position with spacing
        if i == 1 then
            frame:SetPoint("LEFT", iconWrapper, "LEFT", 0, 0)
        else
            frame:SetPoint("LEFT", group.buttons[i - 1], "RIGHT", 16, 0)
        end

        local tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(REACTION_ICONS[i])
        tex:SetAlpha(1)
        tex:Show()
        frame.texture = tex

        -- Remove border entirely
        frame.border = nil

        frame:SetScript("OnClick", function()
            local previous = group:GetSelected()
            if previous == i then
                group:SetSelected(0)
            else
                group:SetSelected(i)
            end
        end)

        frame:Show()
        table.insert(group.buttons, frame)
    end

    -- 🔁 Replace updateHighlight() with tint logic
    local function updateHighlight()
        for i, btn in ipairs(group.buttons) do
            if i == group.selectedIndex then
                btn.texture:SetVertexColor(1, 1, 1) -- full color
            else
                btn.texture:SetVertexColor(0.7, 0.7, 0.7)
            end
        end
    end

    function group:SetSelected(index, silent)
        self.selectedIndex = index
        updateHighlight()
        if not silent and config.onSelect then
            config.onSelect(index)
        end
    end

    function group:GetSelected()
        return self.selectedIndex
    end





    return group
end




local PaneBackdrop  = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
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
    border:SetAllPoints(group.frame)
    border:SetBackdrop(PaneBackdrop)
    border:SetBackdropColor(15/255, 15/255, 15/255, 1)
    border:SetBackdropBorderColor(0.4, 0.4, 0.4)

    return group
end

local function CreateReviewPrompt()
    local frame = AceGUI:Create("CustomFrame")
    local point, relativeTo, relativePoint, xOfs, yOfs = frame.frame:GetPoint()
    frame.frame:ClearAllPoints()
    frame.frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs - 15)

    frame:SetTitle("")
    frame.titlebg:Hide()
    frame.titlebg_l:Hide()
    frame.titlebg_r:Hide()
    frame:SetLayout("Flow")
    frame:SetWidth(350)
    frame:SetHeight(250) -- Adjusted height to better accommodate reactions + text

    ns.CustomFrameSetAllPoints()
    ns.CustomFrameHideBackDrop()

    frame:OnWidthSet(350, true)
    frame:OnHeightSet(250, true) -- Adjusted height

    frame.frame:SetScript("OnHide", function()
        if ns._ratePromptTicker then
            ns._ratePromptTicker:Cancel()
            ns._ratePromptTicker = nil
        end
    end)

    local closeButton = CreateFrame("Button", "GoAHExitButtonDeathRate", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 5, 1)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        OFAuctionFrameDeathClips.openedPromptClipID = nil
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)
    closeButton:SetFrameLevel(frame.frame:GetFrameLevel()+10)

    local reviewGroup = CreateBorderedGroup(1, 250) -- Adjusted height
    reviewGroup:SetPadding(25, 20)
    frame:AddChild(reviewGroup)

    local labelPaddingTop = AceGUI:Create("MinimalFrame")
    labelPaddingTop:SetFullWidth(true)
    labelPaddingTop:SetHeight(10)
    reviewGroup:AddChild(labelPaddingTop)

    local targetLabel = AceGUI:Create("Label")
    targetLabel:SetFontObject(GameFontNormalLarge)
    targetLabel:SetFullWidth(true)
    reviewGroup:AddChild(targetLabel)

    local labelFontString = targetLabel.label
    labelFontString:SetScale(1.5)
    labelFontString:ClearAllPoints()
    labelFontString:SetPoint("LEFT", targetLabel.frame, "LEFT", 3, 0)

    local playedLabel = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    playedLabel:SetPoint("LEFT", targetLabel.frame, "LEFT", 4, -30)
    playedLabel:SetText("Время в игре:")

    local playedTime = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playedTime:SetPoint("TOPRIGHT", closeButton, "BOTTOMLEFT", -3, -36)
    playedTime:SetText("")
    playedTime:SetTextColor(1, 1, 1, 1)

    local playedTimeWrapper = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    playedTimeWrapper:SetPoint("TOPRIGHT", closeButton, "BOTTOMLEFT", -3, -36)
    playedTimeWrapper:SetSize(150, 20)
    playedTimeWrapper:EnableMouse(true)
    playedTimeWrapper:SetFrameStrata("TOOLTIP")

    local labelPaddingMid = AceGUI:Create("MinimalFrame")
    labelPaddingMid:SetFullWidth(true)
    labelPaddingMid:SetHeight(25) -- Reduced from 25 to make space for reaction icons
    reviewGroup:AddChild(labelPaddingMid)

    local reviewEdit = AceGUI:Create("MultiLineEditBoxCustom")
    local submitButton -- Declare submitButton here to be accessible in reactionWidget's onSelect

    -- 🟨 REPLACE STAR WIDGET SETUP HERE IN PROMPT CREATION
    -- COMMENT OUT OR DELETE THE EXISTING starRating CODE BLOCK:
    -- local starRating = ns.CreateStarRatingWidget({...})
    -- reviewGroup:AddChild(starRating)

    -- 🔄 REPLACE WITH THIS:
    local reactionWidget = CreateReactionWidget({
        onSelect = function(index)
            local text = reviewEdit:GetText()
            if index > 0 and (text == "" or text == REVIEW_PLACEHOLDER) then
                submitButton:SetDisabled(false)
                submitButton.frame:Click()
            else
                submitButton:SetDisabled(index == 0 and (text == "" or text == REVIEW_PLACEHOLDER))
            end
        end,
        iconSize = 36, -- Slightly smaller icons if needed
        height = 42,   -- Adjusted height for reaction widget
    })
    reviewGroup:AddChild(reactionWidget)

    local paddingAfterReactions = AceGUI:Create("MinimalFrame")
    paddingAfterReactions:SetFullWidth(true)
    paddingAfterReactions:SetHeight(5) -- Space between reactions and text box
    reviewGroup:AddChild(paddingAfterReactions)

    reviewEdit:SetLabel("")
    reviewEdit:SetWidth(400)
    reviewEdit:DisableButton(true)
    reviewEdit:SetMaxLetters(30)
    reviewEdit:SetHeight(50) -- Adjusted height for review box
    reviewEdit.editBox:SetFontObject(GameFontNormal)
    reviewEdit.editBox:SetTextColor(1, 1, 1, 0.75)
    reviewEdit.editBox:SetTextInsets(6, 6, 6, 6)
    reviewGroup:AddChild(reviewEdit)

    local paddingAfterEditBox = AceGUI:Create("MinimalFrame")
    paddingAfterEditBox:SetFullWidth(true)
    paddingAfterEditBox:SetHeight(5) -- Space between text box and submit button
    reviewGroup:AddChild(paddingAfterEditBox)

    submitButton = AceGUI:Create("PKBTRedButton")
    submitButton:SetFullWidth(true)
    submitButton:SetHeight(35) -- Adjusted height for submit button
    submitButton:SetText(L["Submit Review"])
    submitButton:SetDisabled(true)
    reviewGroup:AddChild(submitButton)

    reviewEdit.editBox:SetScript("OnEditFocusGained", function(self)
        if reviewEdit:GetText() == REVIEW_PLACEHOLDER then
            reviewEdit:SetText("")
        end
    end)
    reviewEdit.editBox:SetScript("OnEditFocusLost", function(self)
        if reviewEdit:GetText() == "" then
            reviewEdit:SetText(REVIEW_PLACEHOLDER)
        end
    end)
    reviewEdit.editBox:SetScript("OnTextChanged", function(self)
        local text = reviewEdit:GetText()
        local selected = reactionWidget:GetSelected()
        submitButton:SetDisabled(selected == 0 and (text == "" or text == REVIEW_PLACEHOLDER))
    end)

    local prompt = {
        frame = frame,
        closeButton = closeButton,
        targetLabel = targetLabel,
        labelFontString = labelFontString,
        playedTime = playedTime,
        playedTimeWrapper = playedTimeWrapper, -- Added for potential external access if needed
        reactionWidget = reactionWidget,
        reviewEdit = reviewEdit,
        submitButton = submitButton,
        playedTimeTooltipData = {} -- Initialize this sub-table
    }

    local RateTip = CreateFrame("GameTooltip", "GoAgainAH_RateTooltip", UIParent, "GameTooltipTemplate")
    RateTip:SetPadding(8, 8)

    local RateTipHeader = RateTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    RateTipHeader:SetPoint("TOP", RateTip, "TOP", 0, -16)
    RateTipHeader:SetJustifyH("CENTER")
    RateTipHeader:SetFontObject("PKBT_Font_16")

    local function UpdateTooltipPosition(self)
        if not RateTip:IsOwned(self) then return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        RateTip:ClearAllPoints()
        RateTip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 12)
    end

    playedTimeWrapper:SetScript("OnEnter", function(self)
        local tip = prompt.playedTimeTooltipData       -- краткое имя
        RateTip:SetOwner(self, "ANCHOR_NONE")
        RateTip:ClearLines()
        self:SetScript("OnUpdate", UpdateTooltipPosition)

        RateTipHeader:SetText("Средние значения:")
        RateTipHeader:SetTextColor(0.9, 0.8, 0.5)
        RateTip:AddLine(" ")
        RateTip:AddLine(" ")

        -- проверяем наличие данных
        if tip and tip.medium_boundary and tip.legend_first then
            local LABEL_WIDTH, SPACING = 100, 6

            local function AddRow(label, value, lr, lg, lb, rr, rg, rb)
                local timeStr = value and SecondsToTime(value) or "N/A"
                RateTip:AddDoubleLine(("     "):rep(1)..label, timeStr,
                        lr, lg, lb, rr, rg, rb)

                local num      = RateTip:NumLines()
                local leftFS   = _G["GoAgainAH_RateTooltipTextLeft"..num]
                local rightFS  = _G["GoAgainAH_RateTooltipTextRight"..num]

                if leftFS then
                    leftFS:SetWidth(LABEL_WIDTH)
                    leftFS:SetJustifyH("LEFT")
                end
                if rightFS and leftFS then
                    rightFS:ClearAllPoints()
                    rightFS:SetPoint("LEFT", leftFS, "RIGHT", SPACING, 0)
                    rightFS:SetJustifyH("LEFT")
                    rightFS:SetWidth(rightFS:GetStringWidth() - 30)
                end
            end

            -- ❯❯ показываем ПЕРВЫЕ значения категорий
            AddRow("Легенда",    tip.legend_first, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0)   -- зелёный
            AddRow("Быстро",     tip.fast_first,   1.0, 1.0, 0.0, 1.0, 1.0, 0.0)   -- жёлтый
            AddRow("Средне",     tip.medium_first, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)   -- белый
            AddRow("Медленно",   tip.slow_first,   1.0, 0.5, 0.0, 1.0, 0.5, 0.0)   -- оранжевый
            AddRow("Своя волна", tip.wave_first,   1.0, 0.0, 0.0, 1.0, 0.0, 0.0)   -- красный

            RateTip:AddLine(" ")

            -- цвет строки «Ранг» по границам
            local played = tip.playedTime or 0
            local cr,cg,cb = 1,1,1
            if     played <= tip.legend_boundary then cr,cg,cb = 0.0, 1.0, 0.0
            elseif played <= tip.fast_boundary   then cr,cg,cb = 1.0, 1.0, 0.0
            elseif played <= tip.medium_boundary then cr,cg,cb = 1.0, 1.0, 1.0
            elseif played <= tip.slow_boundary   then cr,cg,cb = 1.0, 0.5, 0.0
            else                                   cr,cg,cb = 1.0, 0.0, 0.0
            end

            local rankStr = tip.rank and tip.maxRank
                    and string.format(" %s из %s", tip.rank, tip.maxRank)
                    or " N/A"
            RateTip:AddLine("|cffffd100Ранг:|r"..rankStr, cr, cg, cb)

            local last = _G["GoAgainAH_RateTooltipTextLeft"..RateTip:NumLines()]
            if last then
                last:SetFontObject("PKBT_Font_16")
                last:ClearAllPoints()
                last:SetPoint("BOTTOM", RateTip, "BOTTOM", 0, 16)
                last:SetJustifyH("CENTER")
            end
        else
            RateTip:AddLine("    Недостаточно данных для оценки", 1, 1, 1)
        end
        RateTip:Show()
    end)

    playedTimeWrapper:SetScript("OnLeave", function(self)
        RateTip:Hide()
        self:SetScript("OnUpdate", nil)
    end)

    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
        C_Timer:After(0.001, function()
            if self.labelFontString then
                self.labelFontString:SetScale(1.5)
                self.labelFontString:ClearAllPoints()
                self.labelFontString:SetPoint("LEFT", self.targetLabel.frame, "LEFT", 3, 0)
            end
        end)
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
        if ns._ratePromptTicker then
            ns._ratePromptTicker:Cancel()
            ns._ratePromptTicker = nil
        end
    end

    function prompt:SetTargetName(name, classColor)
        self.targetLabel:SetText(name)
        if classColor then
            self.labelFontString:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            self.labelFontString:SetTextColor(1, 1, 1)
        end
    end

    function prompt:SetPlayedTime(seconds, clip)
        -- очистить предыдущие данные
        self.playedTimeTooltipData = {}

        if seconds and clip and clip.level then
            playedLabel:Show()
            playedLabel:SetText("Время в игре:")
            self.playedTime:SetText(SecondsToTime(seconds))

            -- получаем цвет и данные от GetPlayedTimeColor
            local r_player, g_player, b_player,
            median_boundary, p25_boundary, p75_boundary,
            rank_val, maxRank_val,
            legend_boundary, fast_boundary, medium_boundary, slow_boundary, wave_boundary,
            legend_first, fast_first, medium_first, slow_first, wave_first
            = ns.GetPlayedTimeColor(seconds, clip.level)

            self.playedTime:SetTextColor(r_player, g_player, b_player, 1)

            -- сохранить в tip для тултипа
            local tip = self.playedTimeTooltipData

            -- примеры
            tip.legend_first = legend_first
            tip.fast_first   = fast_first
            tip.medium_first = medium_first
            tip.slow_first   = slow_first
            tip.wave_first   = wave_first

            -- границы
            tip.legend_boundary = legend_boundary
            tip.fast_boundary   = fast_boundary
            tip.medium_boundary = medium_boundary
            tip.slow_boundary   = slow_boundary
            tip.wave_boundary   = wave_boundary

            tip.playedTime = seconds
            tip.rank       = rank_val
            tip.maxRank    = maxRank_val
            tip.r_player, tip.g_player, tip.b_player = r_player, g_player, b_player

            -- cancel any existing countdown ticker
            if ns._ratePromptTicker then
                ns._ratePromptTicker:Cancel()
                ns._ratePromptTicker = nil
            end

        elseif ns.nextUpdateDeadline then
            -- your “обновится через” branch (unchanged)
            playedLabel:Show()
            playedLabel:SetText("Обновится через:")
            self.playedTime:SetText(SecondsToTime(ns.nextUpdateDeadline - time()))
            self.playedTime:SetTextColor(0.6, 0.6, 0.6, 1)
            self.playedTimeTooltipData.median_boundary = nil

            if not ns._ratePromptTicker then
                ns._ratePromptTicker = C_Timer:NewTicker(1, function()
                    if self.frame:IsShown() and ns.nextUpdateDeadline then
                        local remaining = ns.nextUpdateDeadline - time()
                        if remaining <= 0 then
                            -- countdown over → recurse or show error
                            if clip and clip.playedTime then
                                self:SetPlayedTime(clip.playedTime, clip)
                            else
                                playedLabel:SetText("Время в игре:")
                                self.playedTime:SetText("N/A")
                                self.playedTime:SetTextColor(1, 0, 0, 1)
                                self.playedTimeTooltipData = {}
                            end
                            if ns._ratePromptTicker then
                                ns._ratePromptTicker:Cancel()
                                ns._ratePromptTicker = nil
                            end
                        else
                            self.playedTime:SetText(SecondsToTime(remaining))
                        end
                    elseif ns._ratePromptTicker then
                        ns._ratePromptTicker:Cancel()
                        ns._ratePromptTicker = nil
                    end
                end)
            end

        else
            -- final fallback (unchanged)
            playedLabel:Show()
            playedLabel:SetText("Обновится через:")
            self.playedTime:SetText("~10 минут")
            self.playedTime:SetTextColor(1, 1, 1, 1)
            self.playedTimeTooltipData = {}
            if ns._ratePromptTicker then
                ns._ratePromptTicker:Cancel()
                ns._ratePromptTicker = nil
            end
        end
    end


    function prompt:OnSubmit(callback)
        self.submitButton:SetCallback("OnClick", function()
            callback(self.reactionWidget:GetSelected(), self.reviewEdit:GetText() == REVIEW_PLACEHOLDER and "" or self.reviewEdit:GetText())
        end)
    end

    function prompt:OnCancel(callback)
        self.closeButton:SetScript("OnClick", function()
            self.frame:Hide()
            OFAuctionFrameDeathClips.openedPromptClipID = nil
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update()
            end
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
            if callback then callback() end
        end)
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.EV_PLAYED_TIME_UPDATED, function(id)
        if not id or not prompt or not prompt.frame:IsShown() then return end
        if OFAuctionFrameDeathClips.openedPromptClipID ~= id then return end

        local clip = ns.GetLiveDeathClips()[id]
        if clip and clip.playedTime then
            prompt:SetPlayedTime(clip.playedTime, clip)
        end
    end)

    return prompt
end


local function GetReviewPrompt()
    if not reviewPrompt then
        reviewPrompt = CreateReviewPrompt()
    end
    return reviewPrompt
end

function ns.ShowDeathClipRatePrompt(clip, overrideUser)
    if not clip then
        print(ChatPrefixError() .. L[" Warning: failed to open rate clip popup, missing clip"])
        return
    end
    if not clip.id then
        print(ChatPrefixError() .. L[" Warning: failed to open rate clip popup, missing clip ID"])
        return
    end
    local me = overrideUser or UnitName("player")
    local state = ns.GetDeathClipReviewState()
    local reviewID = ns.GetClipReviewID(clip.id, me)
    local review = state:GetReview(reviewID)
    local hasExistingReview, existingRating, existingText
    if review then
        hasExistingReview = true
        existingRating = review.rating
        existingText = review.note
    else
        hasExistingReview = false
    end

    local prompt = GetReviewPrompt()

    -- Reset the form
    --prompt.starRating:SetRating(existingRating or 0)
    -- 🟥 In prompt:Show or review loader, set selection if review exists:
    prompt.reactionWidget:SetSelected(existingRating or 0, true)
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
    -- Set class color from RAID_CLASS_COLORS within the current scope
    local classColor = RAID_CLASS_COLORS[clip.class]
    if classColor then
        -- Now pass both the name and classColor when calling SetTargetName
        prompt:SetTargetName(ns.GetDisplayName(clip.characterName), classColor)
    else
        -- If no class color, pass nil as the second argument
        prompt:SetTargetName(ns.GetDisplayName(clip.characterName), nil)
    end

    prompt:SetPlayedTime(clip.playedTime, clip)


    prompt:OnSubmit(function(rating, text)
        local finalText = text == REVIEW_PLACEHOLDER and "" or text
        state:UpdateReview(reviewID, me, clip.id, rating, finalText)
        prompt:Hide()
        OFAuctionFrameDeathClips.openedPromptClipID = nil
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update() -- Refresh highlights
        end
    end)

    prompt:OnCancel(function()
        -- Optional cancel callback
    end)

    prompt:Show()
    reviewPrompt = prompt
end
-- Add this function with the other ns functions
ns.HideDeathClipRatePrompt = function()
    if reviewPrompt and reviewPrompt.frame:IsShown() then
        reviewPrompt:Hide()
    end
    if ns._ratePromptTicker then
        ns._ratePromptTicker:Cancel()
        ns._ratePromptTicker = nil
    end
end

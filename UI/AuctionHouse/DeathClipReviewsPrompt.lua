local _, ns = ...
local L = ns.L

local AceGUI = LibStub("AceGUI-3.0")

-- Local Variables for Layout Customization
local frameWidth = 380                    -- Main frame width
local frameHeight = 520                   -- Main frame total height (reduced by 30px)
local frameVerticalOffset = -15           -- Frame vertical positioning offset
local borderedGroupHeight = 500           -- Height of the main bordered group (reduced by 30px)
local borderedGroupPadding = 25           -- Horizontal padding for bordered group
local borderedGroupVerticalPadding = 20   -- Vertical padding for bordered group
local headerTopPadding = 10               -- Top padding before header
local headerScale = 1.5                   -- Scale factor for header text
local headerLeftOffset = 3                -- Left offset for header text
local playedTimeVerticalOffset = -35      -- Vertical offset for played time from header (increased spacing)
local playedTimeLeftOffset = 4            -- Left offset for played time label
local playedTimeRightOffset = -10         -- Right offset for played time value
local levelRankVerticalOffset = -60       -- Vertical offset for level/rank from header (5px more from time)
local midPadding = 25                     -- Padding between level/rank and emotion section (increased by 15px)
local emotionSummaryHeight = 60           -- Height of emotion summary widget
local emotionSummaryWidth = 320           -- Width of emotion summary widget
local emotionIconSize = 40                -- Size of emotion icons
local emotionLabelHeight = 25             -- Height of emotion label container
local emotionContainerHeight = 70         -- Height of emotion container
local emotionContainerVerticalOffset = -5 -- Vertical offset for emotion summary
local scrollFrameWidth = 300              -- Width of scroll frame (MAIN CONTROL)
local scrollFrameHeight = 230             -- Height of scroll frame
local scrollFrameHorizontalOffset = -14   -- Horizontal offset for scroll frame (moved further left for scrollbar)
local scrollFrameVerticalOffset = -10     -- Vertical offset for scroll frame
local scrollContainerHeight = 250         -- Height of scroll container (reduced)
local scrollEntryWidth = scrollFrameWidth - 5  -- Width calculated from scroll frame (320-5=315)
local scrollEntryHeight = 75              -- Height of each review entry (increased for 3 entries)
local scrollEntrySpacing = 1              -- Spacing between entries (minimal)
local scrollEntryPadding = 12             -- Internal padding for entries (slightly increased)
local scrollEntryLeftOffset = 2           -- Left offset for entry positioning
local scrollEntryIconSize = 18            -- Size of emotion icons in entries (slightly smaller)
local scrollEntryIconOffset = -12         -- Right offset for entry icons (restored to normal)
local scrollEntryTextVerticalOffset = -26 -- Vertical offset for entry text (adjusted for more spacing)
local scrollEntryTextRightOffset = -32    -- Right offset for entry text (restored to normal)
local scrollEntryTextHeight = 40          -- Height for multi-line text
local scrollSeparatorLeftOffset = 2       -- Left offset for separator lines
local scrollSeparatorRightOffset = -2     -- Right offset for separator lines
local maxScrollEntries = 3                -- Maximum visible entries at once (reduced to 3)
local buttonPaddingHeight = 0           -- Negative padding to bring button closer (more space saving)
local buttonContainerHeight = 45          -- Height of button container (slightly larger for better button)
local buttonWidth = scrollFrameWidth +1 -- Width calculated from scroll frame (320+35=355)
local buttonHeight = 35                   -- Height of write review button
local tooltipPadding = 8                  -- Tooltip padding
local tooltipHeaderVerticalOffset = -16   -- Vertical offset for tooltip header
local tooltipSpacing = 6                  -- Spacing in tooltip between elements
local tooltipLabelWidth = 100             -- Width of tooltip labels
local scrollEntryNameToTextSpacing = 4    -- Additional spacing between name and review text

-- Same reaction icons as in rate prompt
local REACTION_ICONS = {
    [1] = "Interface\\AddOns\\GoAgainAH\\Media\\smiley_64x64.tga",       -- 😂 Funny
    [2] = "Interface\\AddOns\\GoAgainAH\\Media\\eyes_64x64.tga",      -- 🕯️ Sad
    [3] = "Interface\\AddOns\\GoAgainAH\\Media\\clown_64x64.tga",       -- ♿ Boring
    [4] = "Interface\\AddOns\\GoAgainAH\\Media\\fire_64x64.tga",        -- 💪 Heroic
}

local PaneBackdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

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

local function CreateEmotionSummaryWidget(reviews)
    local group = AceGUI:Create("MinimalFrame")
    group:SetHeight(emotionSummaryHeight)
    group:SetWidth(emotionSummaryWidth)
    group:SetLayout("Flow")
    group:Show()

    local ICON_SIZE = emotionIconSize
    local TOTAL_WIDTH = emotionSummaryWidth
    local ICON_SPACING = (TOTAL_WIDTH - (ICON_SIZE * 4)) / 5 -- Equal spacing including edges
    local iconWrapper = CreateFrame("Frame", nil, group.frame)
    iconWrapper:SetSize(TOTAL_WIDTH, ICON_SIZE + 20)
    iconWrapper:SetPoint("TOPLEFT", group.frame, "TOPLEFT", 0, -10) -- Align to left edge
    group.iconWrapper = iconWrapper

    -- Count emotions from reviews
    local emotionCounts = {0, 0, 0, 0}
    for _, review in ipairs(reviews) do
        if review.rating > 0 and review.rating <= 4 then
            emotionCounts[review.rating] = emotionCounts[review.rating] + 1
        end
    end

    group.emotionFrames = {}

    for i = 1, 4 do
        local frame = CreateFrame("Frame", nil, iconWrapper)
        frame:SetSize(ICON_SIZE + 16, ICON_SIZE + 20)

        -- Position with equal margins on both ends
        local xOffset = ICON_SPACING + (i - 1) * (ICON_SIZE + ICON_SPACING)
        frame:SetPoint("LEFT", iconWrapper, "LEFT", xOffset, 0)

        local tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("TOP", frame, "TOP", 0, 0)
        tex:SetTexture(REACTION_ICONS[i])
        tex:SetAlpha(emotionCounts[i] > 0 and 1 or 0.3)
        tex:Show()
        frame.texture = tex

        local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- Bigger font
        countLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
        countLabel:SetText(tostring(emotionCounts[i]))
        countLabel:SetTextColor(1, 1, 1, 1)
        frame.countLabel = countLabel

        frame:Show()
        table.insert(group.emotionFrames, frame)
    end

    function group:UpdateCounts(newReviews)
        local newCounts = {0, 0, 0, 0}
        for _, review in ipairs(newReviews) do
            if review.rating > 0 and review.rating <= 4 then
                newCounts[review.rating] = newCounts[review.rating] + 1
            end
        end

        for i = 1, 4 do
            self.emotionFrames[i].countLabel:SetText(tostring(newCounts[i]))
            self.emotionFrames[i].texture:SetAlpha(newCounts[i] > 0 and 1 or 0.3)
        end
    end

    return group
end

local function CreateDeathClipReviewsPrompt()
    local frame = AceGUI:Create("CustomFrame")
    local point, relativeTo, relativePoint, xOfs, yOfs = frame.frame:GetPoint()
    frame.frame:ClearAllPoints()
    frame.frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs + frameVerticalOffset)

    frame:SetTitle("")
    frame.titlebg:Hide()
    frame.titlebg_l:Hide()
    frame.titlebg_r:Hide()
    frame:SetLayout("Flow")
    frame:SetWidth(frameWidth)
    frame:SetHeight(frameHeight)

    ns.CustomFrameSetAllPoints()
    ns.CustomFrameHideBackDrop()

    frame:OnWidthSet(frameWidth, true)
    frame:OnHeightSet(frameHeight, true)

    local closeButton = CreateFrame("Button", "GoAHExitButtonDeathReview", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 5, 1)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        OFAuctionFrameDeathClips.openedPromptClipID = nil
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update() -- Refresh highlights
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)
    closeButton:SetFrameLevel(frame.frame:GetFrameLevel()+10)

    local reviewGroup = CreateBorderedGroup(1, borderedGroupHeight)
    reviewGroup:SetPadding(borderedGroupPadding, borderedGroupVerticalPadding)
    frame:AddChild(reviewGroup)

    local labelPaddingTop = AceGUI:Create("MinimalFrame")
    labelPaddingTop:SetFullWidth(true)
    labelPaddingTop:SetHeight(headerTopPadding)
    reviewGroup:AddChild(labelPaddingTop)

    local targetLabel = AceGUI:Create("Label")
    targetLabel:SetFontObject(GameFontNormalLarge)
    targetLabel:SetFullWidth(true)
    reviewGroup:AddChild(targetLabel)

    local labelFontString = targetLabel.label
    labelFontString:SetScale(headerScale)
    labelFontString:ClearAllPoints()
    labelFontString:SetPoint("LEFT", targetLabel.frame, "LEFT", headerLeftOffset, 0)

    -- Add played time display (правильно позиционируем)
    local playedTimeLabel = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер как время
    playedTimeLabel:SetPoint("LEFT", targetLabel.frame, "LEFT", playedTimeLeftOffset, playedTimeVerticalOffset) -- Ближе к заголовку
    playedTimeLabel:SetText("Время в игре:")
    playedTimeLabel:SetTextColor(0.6, 0.6, 0.6, 1) -- Серый цвет

    local playedTime = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Оставили большой шрифт
    playedTime:SetPoint("RIGHT", targetLabel.frame, "RIGHT", playedTimeRightOffset, playedTimeVerticalOffset) -- Справа от заголовка
    playedTime:SetText("")
    playedTime:SetTextColor(1, 1, 1, 1)

    -- Add level and rank display (под played time)
    local levelRankFrame = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    levelRankFrame:SetSize(300, 20)
    levelRankFrame:SetPoint("LEFT", targetLabel.frame, "LEFT", playedTimeLeftOffset, levelRankVerticalOffset) -- Под played time

    -- Only show rank, not level (level is in title now)
    local rankLabel = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rankLabel:SetPoint("LEFT", levelRankFrame, "LEFT", 0, 0)
    rankLabel:SetText("Ранг:")
    rankLabel:SetTextColor(0.6, 0.6, 0.6, 1) -- Серый цвет как у played time

    local rankValue = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rankValue:SetPoint("RIGHT", targetLabel.frame, "RIGHT", playedTimeRightOffset, levelRankVerticalOffset) -- Right aligned like played time
    rankValue:SetText("")
    rankValue:SetTextColor(1, 1, 1, 1)

    -- Create tooltip wrapper for played time
    local playedTimeWrapper = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    playedTimeWrapper:SetPoint("RIGHT", targetLabel.frame, "RIGHT", playedTimeRightOffset, playedTimeVerticalOffset) -- Точно над played time
    playedTimeWrapper:SetSize(150, 20)
    playedTimeWrapper:EnableMouse(true)
    playedTimeWrapper:SetFrameStrata("TOOLTIP")

    -- Create tooltip wrapper for rank (reuses same tooltip)
    local rankWrapper = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    rankWrapper:SetPoint("RIGHT", targetLabel.frame, "RIGHT", playedTimeRightOffset, levelRankVerticalOffset) -- Same position as rank value
    rankWrapper:SetSize(150, 20)
    rankWrapper:EnableMouse(true)
    rankWrapper:SetFrameStrata("TOOLTIP")

    local labelPaddingMid = AceGUI:Create("MinimalFrame")
    labelPaddingMid:SetFullWidth(true)
    labelPaddingMid:SetHeight(midPadding) -- Увеличили отступ между level/rank и Player Reactions (было 35px)
    reviewGroup:AddChild(labelPaddingMid)

    -- Emotion summary widget placeholder
    local emotionSummary = nil

    local ScrollBackdrop = {
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
        edgeSize = 16,
        insets = { left = 4, right = 3, top = 4, bottom = 3 }
    }

    -- Create NATIVE WoW ScrollFrame (not AceGUI) to avoid visibility bugs
    local scrollFrame = CreateFrame("ScrollFrame", "DeathClipReviewsScrollFrame", UIParent, "FauxScrollFrameTemplate")
    scrollFrame:SetSize(scrollFrameWidth, scrollFrameHeight) -- Make narrower to match text widths above
    -- Позиционирование будет установлено после создания контейнера
    scrollFrame:SetBackdrop(ScrollBackdrop)
    scrollFrame:SetBackdropColor(0, 0, 0)
    scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.4)

    -- Create entry buttons for native ScrollFrame
    local ENTRY_HEIGHT = scrollEntryHeight
    local MAX_ENTRIES = maxScrollEntries -- Visible entries at once
    scrollFrame.buttons = {}

    for i = 1, MAX_ENTRIES do
        local button = CreateFrame("Frame", nil, scrollFrame)
        button:SetSize(scrollEntryWidth, ENTRY_HEIGHT - scrollEntrySpacing)
        -- Remove backdrop - no more individual frames
        button:EnableMouse(true) -- Enable mouse for hover effects

        if i == 1 then
            button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", scrollEntryLeftOffset, -scrollEntrySpacing)
        else
            button:SetPoint("TOPLEFT", scrollFrame.buttons[i-1], "BOTTOMLEFT", 0, -scrollEntrySpacing)
        end

        -- Add separator line (except for first entry)
        if i > 1 then
            button.separator = button:CreateTexture(nil, "OVERLAY")
            button.separator:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.separator:SetVertexColor(0.3, 0.3, 0.3, 0.8) -- Dark gray separator
            button.separator:SetHeight(1)
            button.separator:SetPoint("TOPLEFT", button, "TOPLEFT", scrollSeparatorLeftOffset, 0)
            button.separator:SetPoint("TOPRIGHT", button, "TOPRIGHT", scrollSeparatorRightOffset, 0)
        end

        -- Add hover effect
        button.hoverTexture = button:CreateTexture(nil, "BACKGROUND")
        button.hoverTexture:SetAllPoints()
        button.hoverTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
        button.hoverTexture:SetVertexColor(0.2, 0.2, 0.2, 0.3) -- Subtle hover highlight
        button.hoverTexture:Hide()

        button:SetScript("OnEnter", function(self)
            self.hoverTexture:Show()
        end)
        button:SetScript("OnLeave", function(self)
            self.hoverTexture:Hide()
        end)

        -- Player name
        button.nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.nameLabel:SetPoint("TOPLEFT", button, "TOPLEFT", scrollEntryPadding, -6) -- Adjusted for smaller height
        button.nameLabel:SetTextColor(1, 1, 1, 1)

        -- Emotion icon
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(scrollEntryIconSize, scrollEntryIconSize)
        button.icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", scrollEntryIconOffset, -4) -- More space for scrollbar

        -- Review text (larger font)
        button.textLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- Changed from GameFontHighlightSmall to GameFontNormal
        button.textLabel:SetPoint("TOPLEFT", button, "TOPLEFT", scrollEntryPadding, scrollEntryTextVerticalOffset - scrollEntryNameToTextSpacing) -- Added extra spacing
        button.textLabel:SetPoint("TOPRIGHT", button, "TOPRIGHT", scrollEntryTextRightOffset, scrollEntryTextVerticalOffset - scrollEntryNameToTextSpacing) -- More space for scrollbar
        button.textLabel:SetHeight(scrollEntryTextHeight) -- Set explicit height for multi-line text
        button.textLabel:SetJustifyH("LEFT")
        button.textLabel:SetJustifyV("TOP") -- Align text to top
        button.textLabel:SetTextColor(0.9, 0.9, 0.9, 1)
        button.textLabel:SetWordWrap(true)

        button:Hide()
        scrollFrame.buttons[i] = button
    end

    -- No reviews message
    local noReviewsLabel = AceGUI:Create("Label")
    noReviewsLabel:SetFullWidth(true)
    noReviewsLabel:SetText(L["There are no reviews for this clip yet."])
    noReviewsLabel:SetJustifyH("CENTER")
    noReviewsLabel.label:SetTextColor(0.6, 0.6, 0.6, 1)
    noReviewsLabel.frame:SetParent(scrollFrame)
    noReviewsLabel.frame:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
    noReviewsLabel.frame:Hide() -- Hide by default

    -- Create containers once (not in Setup to prevent duplication)
    local emotionLabelContainer = AceGUI:Create("MinimalFrame")
    emotionLabelContainer:SetFullWidth(true)
    emotionLabelContainer:SetHeight(emotionLabelHeight)
    emotionLabelContainer:SetLayout("Flow")
    reviewGroup:AddChild(emotionLabelContainer)

    local emotionContainer = AceGUI:Create("MinimalFrame")
    emotionContainer:SetFullWidth(true)
    emotionContainer:SetHeight(emotionContainerHeight)
    emotionContainer:SetLayout("Flow")
    reviewGroup:AddChild(emotionContainer)

    -- Removed separator after emotions

    local scrollContainer = AceGUI:Create("MinimalFrame")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(scrollContainerHeight)
    scrollContainer:SetLayout("Flow")
    reviewGroup:AddChild(scrollContainer)

    local buttonPadding = AceGUI:Create("MinimalFrame")
    buttonPadding:SetFullWidth(true)
    buttonPadding:SetHeight(buttonPaddingHeight)
    reviewGroup:AddChild(buttonPadding)

    local buttonContainer = AceGUI:Create("MinimalFrame")
    buttonContainer:SetFullWidth(true)
    buttonContainer:SetHeight(buttonContainerHeight)
    buttonContainer:SetLayout("Flow")
    reviewGroup:AddChild(buttonContainer)

    -- Write review button using same style as RatePrompt
    local writeReviewButton = AceGUI:Create("PKBTRedButton")
    writeReviewButton:SetWidth(buttonWidth)
    writeReviewButton:SetHeight(buttonHeight)
    writeReviewButton:SetText(L["Write Review"])
    buttonContainer:AddChild(writeReviewButton)

    local prompt = {
        frame = frame,
        closeButton = closeButton,
        targetLabel = targetLabel,
        labelFontString = labelFontString,
        levelDisplay = nil, -- Will be created in SetTargetName
        levelWrapper = nil, -- Will be created in SetTargetName
        playedTime = playedTime,
        playedTimeWrapper = playedTimeWrapper,
        rankValue = rankValue,
        rankWrapper = rankWrapper,
        emotionSummary = nil, -- Will be set when reviews are loaded
        emotionLabel = nil, -- Will be set when emotion summary is created
        emotionLabelContainer = emotionLabelContainer,
        emotionContainer = emotionContainer,
        scrollFrame = scrollFrame,
        scrollContainer = scrollContainer,
        writeReviewButton = writeReviewButton,
        noReviewsLabel = noReviewsLabel,
        reviews = {},
        clip = nil,
        playedTimeTooltipData = {} -- For tooltip functionality
    }

    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
        C_Timer:After(0.001, function()
            if self.labelFontString then
                self.labelFontString:SetScale(headerScale)
                self.labelFontString:ClearAllPoints()
                self.labelFontString:SetPoint("LEFT", self.targetLabel.frame, "LEFT", headerLeftOffset, 0)
            end
        end)
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
        -- Clean up ticker when hiding
        if ns._reviewPromptTicker then
            ns._reviewPromptTicker:Cancel()
            ns._reviewPromptTicker = nil
        end
    end

    function prompt:SetTargetName(name, classColor, level)
        -- Show only name in title
        self.targetLabel:SetText(name)
        if classColor then
            self.labelFontString:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            self.labelFontString:SetTextColor(1, 1, 1)
        end

        -- Create level display on the right side like played time
        if not self.levelDisplay then
            self.levelDisplay = self.targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            self.levelDisplay:SetPoint("RIGHT", self.targetLabel.frame, "RIGHT", playedTimeRightOffset, 0) -- Same position as played time but for title
            self.levelDisplay:SetTextColor(1, 1, 1, 1)

            -- Create tooltip wrapper for level display
            self.levelWrapper = CreateFrame("Frame", nil, self.targetLabel.frame:GetParent())
            self.levelWrapper:SetPoint("RIGHT", self.targetLabel.frame, "RIGHT", playedTimeRightOffset, 0) -- Same position as level
            self.levelWrapper:SetSize(100, 20)
            self.levelWrapper:EnableMouse(true)
            self.levelWrapper:SetFrameStrata("TOOLTIP")
        end

        if level then
            self.levelDisplay:SetText("Уровень " .. tostring(level))
        else
            self.levelDisplay:SetText("")
        end
    end

    -- Add SetPlayedTime function like in rate prompt
    function prompt:SetPlayedTime(seconds, clip)
        -- Clear previous data
        self.playedTimeTooltipData = {}

        if seconds and clip and clip.level then
            self.playedTime:SetText(SecondsToTime(seconds))

            -- Get color and data from GetPlayedTimeColor
            local r_player, g_player, b_player,
            median_boundary, p25_boundary, p75_boundary,
            rank_val, maxRank_val,
            legend_boundary, fast_boundary, medium_boundary, slow_boundary, wave_boundary,
            legend_first, fast_first, medium_first, slow_first, wave_first
            = ns.GetPlayedTimeColor(seconds, clip.level)

            self.playedTime:SetTextColor(r_player, g_player, b_player, 1)

            -- Set rank value only (level is now in title)
            if rank_val and maxRank_val then
                self.rankValue:SetText(string.format("%s из %s", rank_val, maxRank_val))
                self.rankValue:SetTextColor(r_player, g_player, b_player, 1)
            else
                self.rankValue:SetText("N/A")
                self.rankValue:SetTextColor(0.7, 0.7, 0.7, 1)
            end

            -- Save tooltip data
            local tip = self.playedTimeTooltipData
            tip.legend_first = legend_first
            tip.fast_first = fast_first
            tip.medium_first = medium_first
            tip.slow_first = slow_first
            tip.wave_first = wave_first
            tip.legend_boundary = legend_boundary
            tip.fast_boundary = fast_boundary
            tip.medium_boundary = medium_boundary
            tip.slow_boundary = slow_boundary
            tip.wave_boundary = wave_boundary
            tip.playedTime = seconds
            tip.rank = rank_val
            tip.maxRank = maxRank_val
            tip.r_player, tip.g_player, tip.b_player = r_player, g_player, b_player

            -- Cancel any existing countdown ticker
            if ns._reviewPromptTicker then
                ns._reviewPromptTicker:Cancel()
                ns._reviewPromptTicker = nil
            end

        elseif ns.nextUpdateDeadline then
            self.playedTime:SetText(SecondsToTime(ns.nextUpdateDeadline - time()))
            self.playedTime:SetTextColor(0.6, 0.6, 0.6, 1)
            self.rankValue:SetText("Обновляется...")
            self.rankValue:SetTextColor(0.6, 0.6, 0.6, 1)
            self.playedTimeTooltipData.median_boundary = nil

            if not ns._reviewPromptTicker then
                ns._reviewPromptTicker = C_Timer:NewTicker(1, function()
                    if self.frame:IsShown() and ns.nextUpdateDeadline then
                        local remaining = ns.nextUpdateDeadline - time()
                        if remaining <= 0 then
                            -- Countdown over → recurse or show error
                            if clip and clip.playedTime then
                                self:SetPlayedTime(clip.playedTime, clip)
                            else
                                self.playedTime:SetText("N/A")
                                self.playedTime:SetTextColor(1, 0, 0, 1)
                                self.rankValue:SetText("N/A")
                                self.rankValue:SetTextColor(1, 0, 0, 1)
                                self.playedTimeTooltipData = {}
                            end
                            if ns._reviewPromptTicker then
                                ns._reviewPromptTicker:Cancel()
                                ns._reviewPromptTicker = nil
                            end
                        else
                            self.playedTime:SetText(SecondsToTime(remaining))
                        end
                    elseif ns._reviewPromptTicker then
                        ns._reviewPromptTicker:Cancel()
                        ns._reviewPromptTicker = nil
                    end
                end)
            end
        else
            self.playedTime:SetText("~10 минут")
            self.playedTime:SetTextColor(1, 1, 1, 1)
            self.rankValue:SetText("N/A")
            self.rankValue:SetTextColor(0.7, 0.7, 0.7, 1)
            self.playedTimeTooltipData = {}

            -- Cancel ticker if exists
            if ns._reviewPromptTicker then
                ns._reviewPromptTicker:Cancel()
                ns._reviewPromptTicker = nil
            end
        end
    end

    function prompt:UpdateEntry(button, review)
        if not review then
            button:Hide()
            return
        end

        button.nameLabel:SetText(ns.GetDisplayName(review.owner))

        -- Set emotion icon
        if review.rating > 0 and review.rating <= 4 then
            button.icon:SetTexture(REACTION_ICONS[review.rating])
            button.icon:SetAlpha(1)
        else
            button.icon:SetAlpha(0)
        end

        -- Set review text
        if review.note and review.note ~= "" then
            button.textLabel:SetText(review.note)
        else
            button.textLabel:SetText("")
        end

        button:Show()
    end

    function prompt:UpdateReviews()
        local offset = FauxScrollFrame_GetOffset(self.scrollFrame)

        if #self.reviews == 0 then
            self.noReviewsLabel.frame:Show()
            for i = 1, MAX_ENTRIES do
                self.scrollFrame.buttons[i]:Hide()
            end
        else
            self.noReviewsLabel.frame:Hide()

            -- Update visible entries
            for i = 1, MAX_ENTRIES do
                local reviewIndex = offset + i
                local review = self.reviews[reviewIndex]
                self:UpdateEntry(self.scrollFrame.buttons[i], review)
            end
        end

        -- Update scrollbar
        FauxScrollFrame_Update(self.scrollFrame, #self.reviews, MAX_ENTRIES, ENTRY_HEIGHT)

        -- Update emotion summary
        if self.emotionSummary then
            self.emotionSummary:UpdateCounts(self.reviews)
        end
    end

    function prompt:Setup(clip)
        self.clip = clip
        local state = ns.GetDeathClipReviewState()
        self.reviews = state:GetReviewsForClip(clip.id)

        -- TODO: REMOVE - Test fake reviews for scrolling (only add once)
        local hasTestReviews = false
        for _, review in ipairs(self.reviews) do
            if review.owner and string.find(review.owner, "TestPlayer") then
                hasTestReviews = true
                break
            end
        end

        if not hasTestReviews then
            local testReviews = {
                {owner = "TestPlayer1", rating = 1, note = "This was absolutely hilarious! I couldn't stop laughing when he charged into the entire enemy team.", createdAt = GetTime() - 100},
                {owner = "TestPlayer2", rating = 2, note = "So sad to see such a promising push end like this.", createdAt = GetTime() - 200},
                {owner = "TestPlayer3", rating = 3, note = "Boring death, nothing special here.", createdAt = GetTime() - 300},
                {owner = "TestPlayer4", rating = 4, note = "Actually a pretty heroic attempt! Almost worked.", createdAt = GetTime() - 400},
                {owner = "TestPlayer5", rating = 1, note = "LOLOLOL best death clip ever! 10/10 would watch again", createdAt = GetTime() - 500},
                {owner = "TestPlayer6", rating = 2, note = "RIP warrior, you will be missed", createdAt = GetTime() - 600},
                {owner = "TestPlayer7", rating = 1, note = "This clip made my day, thank you for sharing!", createdAt = GetTime() - 700},
                {owner = "TestPlayer8", rating = 4, note = "Respect for trying such a bold move", createdAt = GetTime() - 800},
                {owner = "TestPlayer9", rating = 3, note = "Meh, seen better", createdAt = GetTime() - 900},
                {owner = "TestPlayer10", rating = 1, note = "Comedy gold right here folks!", createdAt = GetTime() - 1000},
                {owner = "TestPlayer11", rating = 2, note = "Another warrior falls...", createdAt = GetTime() - 1100},
                {owner = "TestPlayer12", rating = 4, note = "Bold strategy, almost paid off", createdAt = GetTime() - 1200},
            }

            -- Add test reviews to existing ones
            for _, testReview in ipairs(testReviews) do
                table.insert(self.reviews, testReview)
            end
        end
        -- END TODO: REMOVE

        table.sort(self.reviews, function(l, r) return l.createdAt > r.createdAt end)

        -- Set class color from RAID_CLASS_COLORS
        local classColor = RAID_CLASS_COLORS[clip.class]
        self:SetTargetName(ns.GetDisplayName(clip.characterName), classColor, clip.level)

        -- Set played time with all the logic from rate prompt
        self:SetPlayedTime(clip.playedTime, clip)

        -- Create or update emotion summary widget
        if not self.emotionSummary then
            -- Remove emotion label - no more "Player Reactions:" text

            self.emotionSummary = CreateEmotionSummaryWidget(self.reviews)

            -- Position emotion summary in existing container (centered)
            self.emotionSummary.frame:SetParent(self.emotionContainer.frame)
            self.emotionSummary.frame:SetPoint("CENTER", self.emotionContainer.frame, "CENTER", 0, emotionContainerVerticalOffset)
            self.emotionSummary.frame:Show()
        else
            self.emotionSummary:UpdateCounts(self.reviews)
        end

        -- Position ScrollFrame in existing container (slightly left of center)
        self.scrollFrame:SetParent(self.scrollContainer.frame)
        self.scrollFrame:SetPoint("CENTER", self.scrollContainer.frame, "CENTER", scrollFrameHorizontalOffset, scrollFrameVerticalOffset)

        -- Setup scroll frame
        FauxScrollFrame_SetOffset(self.scrollFrame, 0)
        self.scrollFrame:SetScript("OnVerticalScroll", function(scroll, offset)
            FauxScrollFrame_OnVerticalScroll(scroll, offset, ENTRY_HEIGHT, function()
                self:UpdateReviews()
            end)
        end)

        self:UpdateReviews()

        -- Setup button click handler (AceGUI callback)
        self.writeReviewButton:SetCallback("OnClick", function()
            ns.ShowDeathClipRatePrompt(clip)
            self:Hide()
        end)
    end

    -- Add tooltip functionality (copied from rate prompt)
    local ReviewTip = CreateFrame("GameTooltip", "GoAgainAH_ReviewTooltip", UIParent, "GameTooltipTemplate")
    ReviewTip:SetPadding(tooltipPadding, tooltipPadding)

    local ReviewTipHeader = ReviewTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ReviewTipHeader:SetPoint("TOP", ReviewTip, "TOP", 0, tooltipHeaderVerticalOffset)
    ReviewTipHeader:SetJustifyH("CENTER")
    ReviewTipHeader:SetFontObject("PKBT_Font_16")

    local function UpdateTooltipPosition(self)
        if not ReviewTip:IsOwned(self) then return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ReviewTip:ClearAllPoints()
        ReviewTip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 12)
    end

    playedTimeWrapper:SetScript("OnEnter", function(self)
        local tip = prompt.playedTimeTooltipData
        ReviewTip:SetOwner(self, "ANCHOR_NONE")
        ReviewTip:ClearLines()
        self:SetScript("OnUpdate", UpdateTooltipPosition)

        ReviewTipHeader:SetText("Средние значения:")
        ReviewTipHeader:SetTextColor(0.9, 0.8, 0.5)
        ReviewTip:AddLine(" ")
        ReviewTip:AddLine(" ")

        -- Check for data
        if tip and tip.medium_boundary and tip.legend_first then
            local LABEL_WIDTH, SPACING = tooltipLabelWidth, tooltipSpacing

            local function AddRow(label, value, lr, lg, lb, rr, rg, rb)
                local timeStr = value and SecondsToTime(value) or "N/A"
                ReviewTip:AddDoubleLine(("     "):rep(1)..label, timeStr,
                        lr, lg, lb, rr, rg, rb)

                local num = ReviewTip:NumLines()
                local leftFS = _G["GoAgainAH_ReviewTooltipTextLeft"..num]
                local rightFS = _G["GoAgainAH_ReviewTooltipTextRight"..num]

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

            -- Show category values
            AddRow("Легенда",    tip.legend_first, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0)
            AddRow("Быстро",     tip.fast_first,   1.0, 1.0, 0.0, 1.0, 1.0, 0.0)
            AddRow("Средне",     tip.medium_first, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
            AddRow("Медленно",   tip.slow_first,   1.0, 0.5, 0.0, 1.0, 0.5, 0.0)
            AddRow("Своя волна", tip.wave_first,   1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

            ReviewTip:AddLine(" ")

            -- Rank line color by boundaries
            local played = tip.playedTime or 0
            local cr,cg,cb = 1,1,1
            if     played <= tip.legend_boundary then cr,cg,cb = 0.0, 1.0, 0.0
            elseif played <= tip.fast_boundary   then cr,cg,cb = 1.0, 1.0, 0.0
            elseif played <= tip.medium_boundary then cr,cg,cb = 1.0, 1.0, 1.0
            elseif played <= tip.slow_boundary   then cr,cg,cb = 1.0, 0.5, 0.0
            else                                       cr,cg,cb = 1.0, 0.0, 0.0
            end

            local rankStr = tip.rank and tip.maxRank
                    and string.format(" %s из %s", tip.rank, tip.maxRank)
                    or " N/A"
            ReviewTip:AddLine("|cffffd100Ранг:|r"..rankStr, cr, cg, cb)

            local last = _G["GoAgainAH_ReviewTooltipTextLeft"..ReviewTip:NumLines()]
            if last then
                last:SetFontObject("PKBT_Font_16")
                last:ClearAllPoints()
                last:SetPoint("BOTTOM", ReviewTip, "BOTTOM", 0, 16)
                last:SetJustifyH("CENTER")
            end
        else
            ReviewTip:AddLine("    Недостаточно данных для оценки", 1, 1, 1)
        end
        ReviewTip:Show()
    end)

    playedTimeWrapper:SetScript("OnLeave", function(self)
        ReviewTip:Hide()
        self:SetScript("OnUpdate", nil)
    end)

    -- Add same tooltip events for rank wrapper
    rankWrapper:SetScript("OnEnter", function(self)
        local tip = prompt.playedTimeTooltipData
        ReviewTip:SetOwner(self, "ANCHOR_NONE")
        ReviewTip:ClearLines()
        self:SetScript("OnUpdate", UpdateTooltipPosition)

        ReviewTipHeader:SetText("Средние значения:")
        ReviewTipHeader:SetTextColor(0.9, 0.8, 0.5)
        ReviewTip:AddLine(" ")
        ReviewTip:AddLine(" ")

        -- Check for data
        if tip and tip.medium_boundary and tip.legend_first then
            local LABEL_WIDTH, SPACING = tooltipLabelWidth, tooltipSpacing

            local function AddRow(label, value, lr, lg, lb, rr, rg, rb)
                local timeStr = value and SecondsToTime(value) or "N/A"
                ReviewTip:AddDoubleLine(("     "):rep(1)..label, timeStr,
                        lr, lg, lb, rr, rg, rb)

                local num = ReviewTip:NumLines()
                local leftFS = _G["GoAgainAH_ReviewTooltipTextLeft"..num]
                local rightFS = _G["GoAgainAH_ReviewTooltipTextRight"..num]

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

            -- Show category values
            AddRow("Легенда",    tip.legend_first, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0)
            AddRow("Быстро",     tip.fast_first,   1.0, 1.0, 0.0, 1.0, 1.0, 0.0)
            AddRow("Средне",     tip.medium_first, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
            AddRow("Медленно",   tip.slow_first,   1.0, 0.5, 0.0, 1.0, 0.5, 0.0)
            AddRow("Своя волна", tip.wave_first,   1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

            ReviewTip:AddLine(" ")

            -- Rank line color by boundaries
            local played = tip.playedTime or 0
            local cr,cg,cb = 1,1,1
            if     played <= tip.legend_boundary then cr,cg,cb = 0.0, 1.0, 0.0
            elseif played <= tip.fast_boundary   then cr,cg,cb = 1.0, 1.0, 0.0
            elseif played <= tip.medium_boundary then cr,cg,cb = 1.0, 1.0, 1.0
            elseif played <= tip.slow_boundary   then cr,cg,cb = 1.0, 0.5, 0.0
            else                                       cr,cg,cb = 1.0, 0.0, 0.0
            end

            local rankStr = tip.rank and tip.maxRank
                    and string.format(" %s из %s", tip.rank, tip.maxRank)
                    or " N/A"
            ReviewTip:AddLine("|cffffd100Ранг:|r"..rankStr, cr, cg, cb)

            local last = _G["GoAgainAH_ReviewTooltipTextLeft"..ReviewTip:NumLines()]
            if last then
                last:SetFontObject("PKBT_Font_16")
                last:ClearAllPoints()
                last:SetPoint("BOTTOM", ReviewTip, "BOTTOM", 0, 16)
                last:SetJustifyH("CENTER")
            end
        else
            ReviewTip:AddLine("    Недостаточно данных для оценки", 1, 1, 1)
        end
        ReviewTip:Show()
    end)

    rankWrapper:SetScript("OnLeave", function(self)
        ReviewTip:Hide()
        self:SetScript("OnUpdate", nil)
    end)

    -- Add tooltip events for level wrapper (same tooltip as played time and rank)
    local function SetupLevelTooltip()
        if not prompt.levelWrapper then return end

        prompt.levelWrapper:SetScript("OnEnter", function(self)
            local tip = prompt.playedTimeTooltipData
            ReviewTip:SetOwner(self, "ANCHOR_NONE")
            ReviewTip:ClearLines()
            self:SetScript("OnUpdate", UpdateTooltipPosition)

            ReviewTipHeader:SetText("Средние значения:")
            ReviewTipHeader:SetTextColor(0.9, 0.8, 0.5)
            ReviewTip:AddLine(" ")
            ReviewTip:AddLine(" ")

            -- Check for data
            if tip and tip.medium_boundary and tip.legend_first then
                local LABEL_WIDTH, SPACING = tooltipLabelWidth, tooltipSpacing

                local function AddRow(label, value, lr, lg, lb, rr, rg, rb)
                    local timeStr = value and SecondsToTime(value) or "N/A"
                    ReviewTip:AddDoubleLine(("     "):rep(1)..label, timeStr,
                            lr, lg, lb, rr, rg, rb)

                    local num = ReviewTip:NumLines()
                    local leftFS = _G["GoAgainAH_ReviewTooltipTextLeft"..num]
                    local rightFS = _G["GoAgainAH_ReviewTooltipTextRight"..num]

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

                -- Show category values
                AddRow("Легенда",    tip.legend_first, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0)
                AddRow("Быстро",     tip.fast_first,   1.0, 1.0, 0.0, 1.0, 1.0, 0.0)
                AddRow("Средне",     tip.medium_first, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
                AddRow("Медленно",   tip.slow_first,   1.0, 0.5, 0.0, 1.0, 0.5, 0.0)
                AddRow("Своя волна", tip.wave_first,   1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

                ReviewTip:AddLine(" ")

                -- Rank line color by boundaries
                local played = tip.playedTime or 0
                local cr,cg,cb = 1,1,1
                if     played <= tip.legend_boundary then cr,cg,cb = 0.0, 1.0, 0.0
                elseif played <= tip.fast_boundary   then cr,cg,cb = 1.0, 1.0, 0.0
                elseif played <= tip.medium_boundary then cr,cg,cb = 1.0, 1.0, 1.0
                elseif played <= tip.slow_boundary   then cr,cg,cb = 1.0, 0.5, 0.0
                else                                       cr,cg,cb = 1.0, 0.0, 0.0
                end

                local rankStr = tip.rank and tip.maxRank
                        and string.format(" %s из %s", tip.rank, tip.maxRank)
                        or " N/A"
                ReviewTip:AddLine("|cffffd100Ранг:|r"..rankStr, cr, cg, cb)

                local last = _G["GoAgainAH_ReviewTooltipTextLeft"..ReviewTip:NumLines()]
                if last then
                    last:SetFontObject("PKBT_Font_16")
                    last:ClearAllPoints()
                    last:SetPoint("BOTTOM", ReviewTip, "BOTTOM", 0, 16)
                    last:SetJustifyH("CENTER")
                end
            else
                ReviewTip:AddLine("    Недостаточно данных для оценки", 1, 1, 1)
            end
            ReviewTip:Show()
        end)

        prompt.levelWrapper:SetScript("OnLeave", function(self)
            ReviewTip:Hide()
            self:SetScript("OnUpdate", nil)
        end)
    end

    -- Call setup function after prompt is fully initialized
    C_Timer:After(0.1, SetupLevelTooltip)

    return prompt
end

local deathClipReviewsPrompt

ns.ShowDeathClipReviewsPrompt = function(clip)
    local state = ns.GetDeathClipReviewState()
    local playerName = UnitName("player") -- Current player
    local hasRated = false

    -- Check if player already rated this clip
    for _, review in pairs(state.persisted.state) do
        if review.clipID == clip.id and review.owner == playerName then
            hasRated = true
            break
        end
    end

    -- If NOT rated, show RATE PROMPT (hide reviews frame if it exists)
    if not hasRated then
        if deathClipReviewsPrompt then
            deathClipReviewsPrompt:Hide() -- Force-hide reviews frame
        end
        ns.ShowDeathClipRatePrompt(clip)       -- Show rate prompt
        return -- Exit early
    end

    -- If already rated, SHOW REVIEWS FRAME
    if not deathClipReviewsPrompt then
        deathClipReviewsPrompt = CreateDeathClipReviewsPrompt()

        -- Register event handlers for live updates
        local function updateReviews()
            if not deathClipReviewsPrompt or not deathClipReviewsPrompt.frame:IsShown() then
                return
            end
            if deathClipReviewsPrompt.clip == nil then
                return
            end
            deathClipReviewsPrompt:Setup(deathClipReviewsPrompt.clip)
        end

        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, updateReviews)
        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED, updateReviews)

        -- Register for played time updates like in rate prompt
        ns.AuctionHouseAPI:RegisterEvent(ns.EV_PLAYED_TIME_UPDATED, function(id)
            if not id or not deathClipReviewsPrompt or not deathClipReviewsPrompt.frame:IsShown() then return end
            if OFAuctionFrameDeathClips.openedPromptClipID ~= id then return end

            local clip = ns.GetLiveDeathClips()[id]
            if clip and clip.playedTime then
                deathClipReviewsPrompt:SetPlayedTime(clip.playedTime, clip)
            end
        end)
    end

    deathClipReviewsPrompt:Setup(clip)
    deathClipReviewsPrompt:Show()
end

-- Add this function to your ns table (can be placed in either file, but probably better in DeathClipReviewsPrompt.lua)
ns.HideAllClipPrompts = function()
    -- Hide the rate prompt if it exists
    if ns.HideDeathClipRatePrompt then
        ns.HideDeathClipRatePrompt()
    end

    -- Hide the reviews prompt if it exists
    if deathClipReviewsPrompt then
        deathClipReviewsPrompt:Hide()
    end
end

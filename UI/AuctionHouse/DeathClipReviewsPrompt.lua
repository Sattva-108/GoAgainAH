local _, ns = ...
local L = ns.L

local AceGUI = LibStub("AceGUI-3.0")

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
    group:SetHeight(60) -- Taller for bigger icons
    group:SetWidth(320)
    group:SetLayout("Flow")
    group:Show()

    local ICON_SIZE = 40 -- Bigger icons
    local TOTAL_WIDTH = 320 -- Full width to align with scroll frame
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
    frame.frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs - 15)

    frame:SetTitle("")
    frame.titlebg:Hide()
    frame.titlebg_l:Hide()
    frame.titlebg_r:Hide()
    frame:SetLayout("Flow")
    frame:SetWidth(380)
    frame:SetHeight(550) -- Увеличили высоту для лучшего размещения элементов

    ns.CustomFrameSetAllPoints()
    ns.CustomFrameHideBackDrop()

    frame:OnWidthSet(380, true)
    frame:OnHeightSet(550, true)

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

    local reviewGroup = CreateBorderedGroup(1, 550) -- Соответствует высоте фрейма
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

    -- Add played time display (правильно позиционируем)
    local playedTimeLabel = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер как время
    playedTimeLabel:SetPoint("LEFT", targetLabel.frame, "LEFT", 4, -25) -- Ближе к заголовку
    playedTimeLabel:SetText("Время в игре:")
    playedTimeLabel:SetTextColor(0.6, 0.6, 0.6, 1) -- Серый цвет

    local playedTime = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Оставили большой шрифт
    playedTime:SetPoint("RIGHT", targetLabel.frame, "RIGHT", -10, -25) -- Справа от заголовка
    playedTime:SetText("")
    playedTime:SetTextColor(1, 1, 1, 1)

    -- Add level and rank display (под played time)
    local levelRankFrame = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    levelRankFrame:SetSize(300, 20)
    levelRankFrame:SetPoint("LEFT", targetLabel.frame, "LEFT", 4, -45) -- Под played time

    local levelLabel = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер
    levelLabel:SetPoint("LEFT", levelRankFrame, "LEFT", 0, 0)
    levelLabel:SetText("Уровень:")
    levelLabel:SetTextColor(0.6, 0.6, 0.6, 1) -- Серый цвет как у played time

    local levelValue = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер
    levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 5, 0)
    levelValue:SetText("")
    levelValue:SetTextColor(1, 1, 1, 1)

    local rankLabel = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер
    rankLabel:SetPoint("LEFT", levelValue, "RIGHT", 15, 0)
    rankLabel:SetText("Ранг:")
    rankLabel:SetTextColor(0.6, 0.6, 0.6, 1) -- Серый цвет как у played time

    local rankValue = levelRankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Такой же размер
    rankValue:SetPoint("LEFT", rankLabel, "RIGHT", 5, 0)
    rankValue:SetText("")
    rankValue:SetTextColor(1, 1, 1, 1)

    -- Create tooltip wrapper for played time
    local playedTimeWrapper = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    playedTimeWrapper:SetPoint("RIGHT", targetLabel.frame, "RIGHT", -10, -25) -- Точно над played time
    playedTimeWrapper:SetSize(150, 20)
    playedTimeWrapper:EnableMouse(true)
    playedTimeWrapper:SetFrameStrata("TOOLTIP")

    local labelPaddingMid = AceGUI:Create("MinimalFrame")
    labelPaddingMid:SetFullWidth(true)
    labelPaddingMid:SetHeight(45) -- Увеличили отступ между level/rank и Player Reactions (было 35px)
    reviewGroup:AddChild(labelPaddingMid)

    -- Emotion summary widget placeholder
    local emotionSummary = nil

    -- Create NATIVE WoW ScrollFrame (not AceGUI) to avoid visibility bugs
    local scrollFrame = CreateFrame("ScrollFrame", "DeathClipReviewsScrollFrame", UIParent, "FauxScrollFrameTemplate")
    scrollFrame:SetSize(320, 230)
    -- Позиционирование будет установлено после создания контейнера
    scrollFrame:SetBackdrop(PaneBackdrop)
    scrollFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.3)
    scrollFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)

    -- Create entry buttons for native ScrollFrame
    local ENTRY_HEIGHT = 75
    local MAX_ENTRIES = 3 -- Visible entries at once
    scrollFrame.buttons = {}

    for i = 1, MAX_ENTRIES do
        local button = CreateFrame("Frame", nil, scrollFrame)
        button:SetSize(300, ENTRY_HEIGHT - 5)
        button:SetBackdrop(PaneBackdrop)
        button:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        button:SetBackdropBorderColor(0.4, 0.4, 0.4)

        if i == 1 then
            button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 10, -5)
        else
            button:SetPoint("TOPLEFT", scrollFrame.buttons[i-1], "BOTTOMLEFT", 0, -5)
        end

        -- Player name
        button.nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.nameLabel:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -8)
        button.nameLabel:SetTextColor(1, 1, 1, 1)

        -- Emotion icon
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -5)

        -- Review text
        button.textLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.textLabel:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -28)
        button.textLabel:SetPoint("TOPRIGHT", button, "TOPRIGHT", -30, -28)
        button.textLabel:SetJustifyH("LEFT")
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
    emotionLabelContainer:SetHeight(25)
    emotionLabelContainer:SetLayout("Flow")
    reviewGroup:AddChild(emotionLabelContainer)

    local emotionContainer = AceGUI:Create("MinimalFrame")
    emotionContainer:SetFullWidth(true)
    emotionContainer:SetHeight(70) -- Уменьшили на 10px для меньшего отступа между лейблом и иконками
    emotionContainer:SetLayout("Flow")
    reviewGroup:AddChild(emotionContainer)

    local scrollContainer = AceGUI:Create("MinimalFrame")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(260) -- Увеличили высоту для scroll + spacing
    scrollContainer:SetLayout("Flow")
    reviewGroup:AddChild(scrollContainer)

    local buttonPadding = AceGUI:Create("MinimalFrame")
    buttonPadding:SetFullWidth(true)
    buttonPadding:SetHeight(5) -- Уменьшили на 15px отступ между scroll и кнопкой (было 20px)
    reviewGroup:AddChild(buttonPadding)

    local buttonContainer = AceGUI:Create("MinimalFrame")
    buttonContainer:SetFullWidth(true)
    buttonContainer:SetHeight(50) -- Увеличили высоту для кнопки
    buttonContainer:SetLayout("Flow")
    reviewGroup:AddChild(buttonContainer)

    -- Write review button (created once)
    local writeReviewButton = CreateFrame("Button", nil, buttonContainer.frame)
    writeReviewButton:SetSize(320, 35)
    writeReviewButton:SetPoint("CENTER", buttonContainer.frame, "CENTER", 0, -5)
    writeReviewButton:SetText(L["Write Review"])
    writeReviewButton:SetNormalFontObject("GameFontNormal")
    writeReviewButton:SetHighlightFontObject("GameFontHighlight")

    -- Simple red button styling
    local normalTex = writeReviewButton:CreateTexture(nil, "BACKGROUND")
    normalTex:SetAllPoints()
    normalTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    normalTex:SetVertexColor(0.8, 0.2, 0.2, 1)
    writeReviewButton:SetNormalTexture(normalTex)

    local highlightTex = writeReviewButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTex:SetAllPoints()
    highlightTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    highlightTex:SetVertexColor(1.0, 0.3, 0.3, 0.5)
    writeReviewButton:SetHighlightTexture(highlightTex)

    local prompt = {
        frame = frame,
        closeButton = closeButton,
        targetLabel = targetLabel,
        labelFontString = labelFontString,
        playedTime = playedTime,
        playedTimeWrapper = playedTimeWrapper,
        levelValue = levelValue,
        rankValue = rankValue,
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
                self.labelFontString:SetScale(1.5)
                self.labelFontString:ClearAllPoints()
                self.labelFontString:SetPoint("LEFT", self.targetLabel.frame, "LEFT", 3, 0)
            end
        end)
    end

    function prompt:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    end

    function prompt:SetTargetName(name, classColor)
        self.targetLabel:SetText(name .. " - " .. L["Reviews"])
        if classColor then
            self.labelFontString:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            self.labelFontString:SetTextColor(1, 1, 1)
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

            -- Set level and rank values
            self.levelValue:SetText(tostring(clip.level))
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

        elseif ns.nextUpdateDeadline then
            self.playedTime:SetText(SecondsToTime(ns.nextUpdateDeadline - time()))
            self.playedTime:SetTextColor(0.6, 0.6, 0.6, 1)
            self.levelValue:SetText(clip and clip.level and tostring(clip.level) or "N/A")
            self.rankValue:SetText("Обновляется...")
            self.rankValue:SetTextColor(0.6, 0.6, 0.6, 1)
            self.playedTimeTooltipData.median_boundary = nil
        else
            self.playedTime:SetText("~10 минут")
            self.playedTime:SetTextColor(1, 1, 1, 1)
            self.levelValue:SetText(clip and clip.level and tostring(clip.level) or "N/A")
            self.rankValue:SetText("N/A")
            self.rankValue:SetTextColor(0.7, 0.7, 0.7, 1)
            self.playedTimeTooltipData = {}
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
        self:SetTargetName(ns.GetDisplayName(clip.characterName), classColor)

        -- Set played time with all the logic from rate prompt
        self:SetPlayedTime(clip.playedTime, clip)

        -- Create or update emotion summary widget
        if not self.emotionSummary then
            -- Add emotion label FIRST using existing container, aligned with level on X
            self.emotionLabel = self.emotionLabelContainer.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self.emotionLabel:SetPoint("TOPLEFT", self.emotionLabelContainer.frame, "TOPLEFT", 4, -5) -- X=4 как у level
            self.emotionLabel:SetText("Player Reactions:")
            self.emotionLabel:SetTextColor(0.8, 0.8, 0.8, 1)

            self.emotionSummary = CreateEmotionSummaryWidget(self.reviews)

            -- Position emotion summary in existing container (centered)
            self.emotionSummary.frame:SetParent(self.emotionContainer.frame)
            self.emotionSummary.frame:SetPoint("CENTER", self.emotionContainer.frame, "CENTER", 0, -5)
            self.emotionSummary.frame:Show()
        else
            self.emotionSummary:UpdateCounts(self.reviews)
        end

        -- Position ScrollFrame in existing container (slightly left of center)
        self.scrollFrame:SetParent(self.scrollContainer.frame)
        self.scrollFrame:SetPoint("CENTER", self.scrollContainer.frame, "CENTER", -20, -10)

        -- Setup scroll frame
        FauxScrollFrame_SetOffset(self.scrollFrame, 0)
        self.scrollFrame:SetScript("OnVerticalScroll", function(scroll, offset)
            FauxScrollFrame_OnVerticalScroll(scroll, offset, ENTRY_HEIGHT, function()
                self:UpdateReviews()
            end)
        end)

        self:UpdateReviews()

        -- Setup button click handler (button already created)
        self.writeReviewButton:SetScript("OnClick", function()
            ns.ShowDeathClipRatePrompt(clip)
            self:Hide()
        end)
    end

    -- Add tooltip functionality (copied from rate prompt)
    local ReviewTip = CreateFrame("GameTooltip", "GoAgainAH_ReviewTooltip", UIParent, "GameTooltipTemplate")
    ReviewTip:SetPadding(8, 8)

    local ReviewTipHeader = ReviewTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ReviewTipHeader:SetPoint("TOP", ReviewTip, "TOP", 0, -16)
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
            local LABEL_WIDTH, SPACING = 100, 6

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

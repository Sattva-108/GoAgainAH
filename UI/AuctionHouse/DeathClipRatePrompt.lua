local addonName, ns = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local reviewPrompt

-- Placeholder icons used temporarily for each emotion
local REACTION_ICONS = {
    [1] = "Interface\\AddOns\\GoAgainAH\\Media\\laugh_64x64.tga",       -- 😂 Funny
    [2] = "Interface\\AddOns\\GoAgainAH\\Media\\candle_64x64.tga",      -- 🕯️ Sad
    [3] = "Interface\\AddOns\\GoAgainAH\\Media\\wheelchair_64x64.tga", -- ♿ Boring
    [4] = "Interface\\AddOns\\GoAgainAH\\Media\\bicep_64x64.tga",       -- 💪 Heroic
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

    local ICON_SIZE = config.iconSize or 32
    local iconWrapper = CreateFrame("Frame", nil, group.frame)
    iconWrapper:SetSize((ICON_SIZE + 16) * 4, ICON_SIZE)
    iconWrapper:SetPoint("TOP", group.frame, "TOP", 0, -8) -- Top padding

    group.iconWrapper = iconWrapper

    for i = 1, 4 do
        local frame = CreateFrame("Button", nil, iconWrapper)
        frame:SetSize(ICON_SIZE, ICON_SIZE)

        -- Position icons with spacing
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

        local border = frame:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetVertexColor(1, 1, 0)
        border:Hide()
        frame.border = border

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
    frame:SetHeight(250)

    ns.CustomFrameSetAllPoints()
    ns.CustomFrameHideBackDrop()


    -- Here, we're passing `true` to use custom padding
    frame:OnWidthSet(350, true) -- Apply custom width adjustment
    frame:OnHeightSet(250, true) -- Apply custom height adjustment

    frame.frame:SetScript("OnHide", function()
        if ns._ratePromptTicker then
            ns._ratePromptTicker:Cancel()
            ns._ratePromptTicker = nil
        end
    end)


    -- Close button
    local closeButton = CreateFrame("Button", "GoAHExitButtonDeathRate", frame.frame, "UIPanelCloseButton")
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

    ---- Add top padding
    --local topPadding = AceGUI:Create("SimpleGroup")
    --topPadding:SetFullWidth(true)
    --topPadding:SetHeight(4)
    --frame:AddChild(topPadding)

    ----------------------------------------------------------------------------
    -- Review Group
    ----------------------------------------------------------------------------
    local submitButton
    local reviewGroup = CreateBorderedGroup(1, 250)
    reviewGroup:SetPadding(25, 20)
    frame:AddChild(reviewGroup)

    ---- Static label for "Write your review for"
    --local staticLabel = AceGUI:Create("Label")
    --staticLabel:SetFontObject(GameFontNormalLarge) -- Using a larger font object
    --local label = L["Write your review for"]
    --staticLabel:SetText("|cFFFFD100".. label .. "|r")
    --staticLabel:SetHeight(22)  -- Adjusted for larger font size
    --reviewGroup:AddChild(staticLabel)
    --
    ---- Static Played Time label (this will appear below the Target Name)
    --local rateClip = staticLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- Using a larger font object
    --rateClip:SetPoint("TOPLEFT", staticLabel.frame, "TOPRIGHT", 15, 3)
    --rateClip:SetText("Rate Clip")
    --rateClip:SetHeight(22)  -- Adjusted for larger font size

    -- Add padding between name and star
    local labelPadding = AceGUI:Create("MinimalFrame")
    labelPadding:SetFullWidth(true)
    labelPadding:SetHeight(10)
    reviewGroup:AddChild(labelPadding)

    -- Creating the target label
    local targetLabel = AceGUI:Create("Label")
    targetLabel:SetFontObject(GameFontNormalLarge)  -- Using a larger font object
    targetLabel:SetFullWidth(true)
    reviewGroup:AddChild(targetLabel)

    -- Accessing the FontString and setting the text color
    local labelFontString = targetLabel.label  -- Accessing the label field directly
    labelFontString:SetScale(1.5)
    labelFontString:ClearAllPoints()
    labelFontString:SetPoint("LEFT", targetLabel.frame, "LEFT", 3, 0)

    -- Static Played Time label (this will appear below the Target Name)
    local playedLabel = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")  -- Using a larger font object
    playedLabel:SetPoint("LEFT", targetLabel.frame, "LEFT", 4, -30)
    playedLabel:SetText("Время в игре:")

    -- Played time label (created dynamically with CreateFontString and aligned to the right)
    -- Attach it to the closebutton as we need something stable, static.
    local playedTime = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")  -- Using a larger font object
    playedTime:SetPoint("TOPRIGHT", closeButton, "BOTTOMLEFT", -3, -36)
    playedTime:SetText("") -- Set this dynamically later
    playedTime:SetTextColor(1, 1, 1, 1) -- White color with full opacity

    -- Transparent wrapper to enable mouse interaction on playedTime
    local playedTimeWrapper = CreateFrame("Frame", nil, targetLabel.frame:GetParent())
    playedTimeWrapper:SetPoint("TOPRIGHT", closeButton, "BOTTOMLEFT", -3, -36)
    playedTimeWrapper:SetSize(150, 20) -- Size matching the text
    playedTimeWrapper:EnableMouse(true)
    playedTimeWrapper:SetFrameStrata("TOOLTIP")

    -- Add padding between name and star
    local labelPadding = AceGUI:Create("MinimalFrame")
    labelPadding:SetFullWidth(true)
    labelPadding:SetHeight(25)
    reviewGroup:AddChild(labelPadding)

    local reviewEdit = AceGUI:Create("MultiLineEditBoxCustom")

    -- 🟨 REPLACE STAR WIDGET SETUP HERE IN PROMPT CREATION
    -- COMMENT OUT OR DELETE THE EXISTING starRating CODE BLOCK:
    -- local starRating = ns.CreateStarRatingWidget({...})
    -- reviewGroup:AddChild(starRating)

    -- 🔄 REPLACE WITH THIS:
    local reactionWidget = CreateReactionWidget({
        onSelect = function(index)
            local text = reviewEdit:GetText()
            if index > 0 and (text == "" or text == REVIEW_PLACEHOLDER) then
                -- Fast submit
                submitButton:SetDisabled(false)
                submitButton.frame:Click()
            else
                -- Manual submit only when both are empty
                submitButton:SetDisabled(index == 0 and (text == "" or text == REVIEW_PLACEHOLDER))
            end
        end,
        iconSize = 32,
        height = 48,
    })
    reviewGroup:AddChild(reactionWidget)





    ---- Add padding between label and name
    --local labelPadding = AceGUI:Create("MinimalFrame")
    --labelPadding:SetFullWidth(true)
    --labelPadding:SetHeight(2)
    --reviewGroup:AddChild(labelPadding)

    -- Comment box

    reviewEdit:SetLabel("")
    reviewEdit:SetWidth(400)

    reviewEdit:DisableButton(true)
    reviewEdit:SetMaxLetters(30)
    --reviewEdit:SetNumLines(6)
    reviewEdit:SetHeight(60)
    reviewEdit.editBox:SetFontObject(GameFontNormal)
    reviewEdit.editBox:SetTextColor(1, 1, 1, 0.75)
    reviewGroup:AddChild(reviewEdit)


    submitButton = AceGUI:Create("PKBTRedButton")
    submitButton:SetFullWidth(true)
    submitButton:SetHeight(40)
    submitButton:SetText(L["Submit Review"])
    submitButton:SetDisabled(true)

    -- Submit Button
    reviewGroup:AddChild(submitButton)

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

    -- 1) Add some inner padding so the text sits inset
    reviewEdit.editBox:SetTextInsets(6, 6, 6, 6)

    ---- Add padding between info and review group
    --local bottomPadding = AceGUI:Create("MinimalFrame")
    --bottomPadding:SetFullWidth(true)
    --bottomPadding:SetHeight(5)
    --frame:AddChild(bottomPadding)


    -- 🧠 Hook textbox too, to refresh button enable state
    reviewEdit.editBox:SetScript("OnTextChanged", function(self)
        local text = reviewEdit:GetText()
        local selected = reactionWidget:GetSelected()
        submitButton:SetDisabled(selected == 0 and (text == "" or text == REVIEW_PLACEHOLDER))
    end)

    -- Collect references for later access
    local prompt = {
        frame = frame,
        closeButton = closeButton,
        targetLabel = targetLabel,
        labelFontString = labelFontString,
        playedTime = playedTime,
        --starRating = starRating,
        -- 🟥 Modify prompt object refs (add this where `prompt = { ... }` is built)
        reactionWidget = reactionWidget,
        reviewEdit = reviewEdit,
        submitButton = submitButton
    }
    local RateTip = CreateFrame("GameTooltip", "GoAgainAH_RateTooltip", UIParent, "GameTooltipTemplate")
    RateTip:SetPadding(8, 8)  -- если нужно внутренние отступы, как у GameTooltip

    -- создаём FontString для заголовка
    local RateTipHeader = RateTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    RateTipHeader:SetPoint("TOP", RateTip, "TOP", 0, -16)   -- 6px вниз от верхней рамки
    RateTipHeader:SetJustifyH("CENTER")                   -- выравниваем по центру
    RateTipHeader:SetFontObject("PKBT_Font_16")


    local function UpdateTooltipPosition(self)
        if not RateTip:IsOwned(self) then return end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        RateTip:ClearAllPoints()
        RateTip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 12)
    end


    playedTimeWrapper:SetScript("OnEnter", function(self)
        local tip = prompt.playedTimeTooltipData
        RateTip:SetOwner(self, "ANCHOR_NONE")
        RateTip:ClearLines()
        self:SetScript("OnUpdate", UpdateTooltipPosition)

        -- заголовок
        -- ► задаём текст заголовка и его цвет
        RateTipHeader:SetText("Средние значения:")
        RateTipHeader:SetTextColor(0.9, 0.8, 0.5)
        RateTip:AddLine(" ")
        RateTip:AddLine(" ")

        if tip and tip.median and tip.playedTime then
            local LABEL_WIDTH, SPACING = 100, 6
            local function AddRow(label, value, lr, lg, lb, rr, rg, rb)
                local timeStr = SecondsToTime(value)
                RateTip:AddDoubleLine(("     "):rep(1) .. label, timeStr, lr, lg, lb, rr, rg, rb)
                local line    = RateTip:NumLines()
                local leftFS  = _G["GoAgainAH_RateTooltipTextLeft"..line]
                local rightFS = _G["GoAgainAH_RateTooltipTextRight"..line]

                if leftFS then
                    leftFS:SetWidth(LABEL_WIDTH)
                    leftFS:SetJustifyH("LEFT")
                end
                if rightFS and leftFS then
                    rightFS:ClearAllPoints()
                    rightFS:SetPoint("LEFT", leftFS, "RIGHT", SPACING, 0)
                    rightFS:SetJustifyH("LEFT")
                    rightFS:SetWidth( rightFS:GetStringWidth() - 30)
                end
            end


            -- Right-aligned time values
            AddRow("Легенда",   tip.lower,  0.25, 1.0, 0.25, 0.25, 1.0, 0.25)
            AddRow("Быстро",          tip.median, 1.0, 1.0, 0.0,  1.0, 1.0, 0.0)
            AddRow("Средне",         tip.upper,  1.0, 1.0, 1.0,  1.0, 1.0, 1.0)
            AddRow("Медленно", tip.upper * 1.3,  1.0, 0.25, 0.25, 1.0, 0.25, 0.25)

            RateTip:AddLine(" ")

            -- Цвет числа ранга по времени (по сравнению с lower/median/upper)
            local played = tip.playedTime
            local rankColor = {1, 1, 1}

            if played and tip.lower and tip.median and tip.upper then
                if played <= tip.lower then
                    rankColor = {0.25, 1.0, 0.25}
                elseif played <= tip.median then
                    rankColor = {1.0, 1.0, 0.3}
                elseif played <= tip.upper then
                    rankColor = {1.0, 1.0, 1.0}
                else
                    rankColor = {1.0, 0.25, 0.25}
                end
            end

            -- Жёлтый текст WoW: только "Ранг:"
            local label = "|cffffd100Ранг:|r"
            local rankStr = string.format(" %s из %s", tip.rank, tip.maxRank)

            RateTip:AddLine(label .. rankStr, unpack(rankColor))

            local lastLine = _G["GoAgainAH_RateTooltipTextLeft" .. RateTip:NumLines()]
            if lastLine then
                lastLine:SetFontObject("PKBT_Font_16")
                lastLine:ClearAllPoints()
                lastLine:SetPoint("BOTTOM", RateTip, "BOTTOM", 0, 16)
                lastLine:SetJustifyH("CENTER")
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


    ----------------------------------------------------------------------------
    -- Show / Hide
    ----------------------------------------------------------------------------
    function prompt:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()

        -- Ensure changes after frame is rendered, 0.001 :)
        C_Timer:After(0.001, function()
            if self.labelFontString then
                self.labelFontString:SetScale(1.5)  -- Set the scale
                self.labelFontString:ClearAllPoints()  -- Clear any previous points
                -- Position it 3px to the right in X-axis
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

    ----------------------------------------------------------------------------
    -- Setters
    ----------------------------------------------------------------------------
    -- Define the SetTargetName function with an additional parameter for classColor
    function prompt:SetTargetName(name, classColor)
        -- Set the target name
        self.targetLabel:SetText(name)

        -- Set the text color based on classColor (if available)
        if classColor then
            labelFontString:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            labelFontString:SetTextColor(1, 1, 1) -- Fallback to white
        end
    end

    function prompt:SetPlayedTime(seconds, clip)
        if seconds then
            -- Show actual played time
            playedLabel:Show()
            playedLabel:SetText("Время в игре:")
            self.playedTime:SetText(SecondsToTime(seconds))

            local r, g, b, median, lower, upper, rank, maxRank = ns.GetPlayedTimeColor(seconds, clip.level)
            self.playedTime:SetTextColor(r, g, b, 1)

            -- Save maxRank in tooltip data
            self.playedTimeTooltipData = {
                median = median,
                lower = lower,
                upper = upper,
                level = clip.level,
                rank = rank,
                maxRank = maxRank, -- Add this line
                playedTime = clip.playedTime
            }


            -- Stop any active countdown ticker
            if ns._ratePromptTicker then
                ns._ratePromptTicker:Cancel()
                ns._ratePromptTicker = nil
            end
        elseif ns.nextUpdateDeadline then
            -- Show countdown to update
            playedLabel:Show()
            playedLabel:SetText("Обновится через:")
            self.playedTime:SetText(SecondsToTime(ns.nextUpdateDeadline - time()))
            self.playedTime:SetTextColor(0.6, 0.6, 0.6, 1)
            self.playedTimeTooltipData = nil

            -- Start ticker only if not already running
            if not ns._ratePromptTicker then
                ns._ratePromptTicker = C_Timer:NewTicker(1, function()
                    if self.frame:IsShown() and ns.nextUpdateDeadline then
                        local remaining = ns.nextUpdateDeadline - time()

                        if remaining <= 0 then
                            -- Countdown is over, switch to actual playedTime view
                            playedLabel:SetText("Время в игре:")
                            self.playedTime:SetText(SecondsToTime(clip.playedTime or 0))

                            -- Colorize with clip.level (optional)
                            if clip and clip.playedTime and clip.level then
                                local r, g, b, median, lower, upper, rank, maxRank = ns.GetPlayedTimeColor(seconds, clip.level)
                                self.playedTime:SetTextColor(r, g, b, 1)

                                -- Save for tooltip later
                                self.playedTimeTooltipData = {
                                    median = median,
                                    lower = lower,
                                    upper = upper,
                                    level = clip.level,
                                    rank = rank,
                                    maxRank = maxRank, -- Add this line
                                    playedTime = clip.playedTime
                                }
                            end

                            -- Stop the ticker
                            ns._ratePromptTicker:Cancel()
                            ns._ratePromptTicker = nil
                        else
                            -- Still counting down
                            self.playedTime:SetText(SecondsToTime(remaining))
                        end
                    end
                end)

            end
        else
            playedLabel:SetText("Обновится через:")
            self.playedTime:SetText("~10 минут")
            self.playedTime:SetTextColor(1, 1, 1, 1)

            self.playedTimeTooltipData = nil

            -- Also stop ticker if nothing to show
            if ns._ratePromptTicker then
                ns._ratePromptTicker:Cancel()
                ns._ratePromptTicker = nil
            end
        end
    end


    ----------------------------------------------------------------------------
    -- Callbacks
    ----------------------------------------------------------------------------
    function prompt:OnSubmit(callback)
        self.submitButton:SetCallback("OnClick", function()
            -- 🟥 In prompt:OnSubmit block, replace:
            -- callback(self.starRating.rating, self.reviewEdit:GetText())
            -- 🔄 With:
            callback(self.reactionWidget:GetSelected(), self.reviewEdit:GetText())
        end)
    end

    function prompt:OnCancel(callback)
        self.closeButton:SetScript("OnClick", function()
            self.frame:Hide()
            OFAuctionFrameDeathClips.openedPromptClipID = nil
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update() -- Refresh highlights
            end
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
end

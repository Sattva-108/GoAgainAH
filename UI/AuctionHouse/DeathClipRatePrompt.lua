local addonName, ns = ...
local AceGUI = LibStub("AceGUI-3.0")

local PaneBackdrop  = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 5, bottom = 2 }
}

local REVIEW_PLACEHOLDER = "Write your review ..."

local function CreateBorderedGroup(relativeWidth, height)
    local group = AceGUI:Create("MinimalFrame")
    group:SetRelativeWidth(relativeWidth)
    group:SetLayout("Flow")

    if height then
        group:SetHeight(height)
    end

    local border = CreateFrame("Frame", nil, group.frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetBackdrop(PaneBackdrop)
    border:SetBackdropColor(0.15, 0.15, 0.13, 1) -- #272522
    border:SetBackdropBorderColor(0.4, 0.4, 0.4)

    return group
end

local function CreateReviewPrompt()
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle("Rate Clip")
    frame:SetLayout("Flow")
    frame:SetWidth(410)
    frame:SetHeight(330)

    -- Close button
    local closeButton = CreateFrame("Button", "ExitButton", frame.frame, "UIPanelCloseButton")
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

    ----------------------------------------------------------------------------
    -- Review Group
    ----------------------------------------------------------------------------
    local reviewGroup = CreateBorderedGroup(1, 230)
    reviewGroup:SetPadding(10, 15)
    frame:AddChild(reviewGroup)

    -- Static label
    local staticLabel = AceGUI:Create("Label")
    staticLabel:SetFontObject(GameFontNormal)
    staticLabel:SetText("|cFFFFD100Write your review for|r")
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
    submitButton:SetText("Submit Review")
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
    bottomPadding:SetHeight(5)
    frame:AddChild(bottomPadding)

    -- Submit Button
    frame:AddChild(submitButton)


    -- Collect references for later access
    local prompt = {
        frame = frame,
        closeButton = closeButton,
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
    function prompt:SetTargetName(name)
        self.targetLabel:SetText(name)
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

function ns.ShowDeathClipRatePrompt(clip, overrideUser)
    if not clip then
        print(ChatPrefixError() .. " Warning: failed to open rate clip popup, missing clip")
        return
    end
    if not clip.id then
        print(ChatPrefixError() .. " Warning: failed to open rate clip popup, missing clip ID")
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
    prompt.starRating:SetRating(existingRating or 0)
    prompt.reviewEdit:SetText(existingText or REVIEW_PLACEHOLDER)

    -- Reset button state
    prompt.submitButton:SetDisabled((existingRating or 0) == 0)
    prompt.submitButton:SetText(hasExistingReview and "Update Review" or "Submit Review")

    -- Update the display
    prompt:SetTargetName(ns.GetDisplayName(clip.characterName))

    prompt:OnSubmit(function(rating, text)
        local finalText = text == REVIEW_PLACEHOLDER and "" or text
        state:UpdateReview(reviewID, me, clip.id, rating, finalText)
        prompt:Hide()
        ns.ShowDeathClipReviewsPrompt(clip)
    end)

    prompt:OnCancel(function()
        -- Optional cancel callback
    end)

    prompt:Show()
end

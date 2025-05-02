local addonName, ns = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local reviewPrompt

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
    frame:SetTitle("")
    frame.titlebg:Hide()
    frame.titlebg_l:Hide()
    frame.titlebg_r:Hide()
    frame:SetLayout("Flow")
    frame:SetWidth(350)
    frame:SetHeight(350)

    ns.CustomFrameSetAllPoints()
    ns.CustomFrameHideBackDrop()


    -- Here, we're passing `true` to use custom padding
    frame:OnWidthSet(350, true) -- Apply custom width adjustment
    frame:OnHeightSet(350, true) -- Apply custom height adjustment

    -- Close button
    local closeButton = CreateFrame("Button", "GoAHExitButtonDeathRate", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7, 7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        OFAuctionFrameDeathClips.openedPromptClipID = nil
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update() -- Refresh highlights
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)
    closeButton:Hide()

    ---- Add top padding
    --local topPadding = AceGUI:Create("SimpleGroup")
    --topPadding:SetFullWidth(true)
    --topPadding:SetHeight(4)
    --frame:AddChild(topPadding)

    ----------------------------------------------------------------------------
    -- Review Group
    ----------------------------------------------------------------------------
    local submitButton
    local reviewGroup = CreateBorderedGroup(1, 350)
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
    local playedTime = targetLabel.frame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")  -- Using a larger font object
    playedTime:SetPoint("RIGHT", playedLabel, "RIGHT", 176, 0)
    playedTime:SetText("") -- Set this dynamically later
    playedTime:SetTextColor(1, 1, 1, 1) -- White color with full opacity

    -- Add padding between name and star
    local labelPadding = AceGUI:Create("MinimalFrame")
    labelPadding:SetFullWidth(true)
    labelPadding:SetHeight(25)
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
        leftPadding = 5,  -- Set the left padding to 20px
    })


    reviewGroup:AddChild(starRating)



    ---- Add padding between label and name
    --local labelPadding = AceGUI:Create("MinimalFrame")
    --labelPadding:SetFullWidth(true)
    --labelPadding:SetHeight(2)
    --reviewGroup:AddChild(labelPadding)

    -- Comment box
    local reviewEdit = AceGUI:Create("MultiLineEditBoxCustom")
    reviewEdit:SetLabel("")
    reviewEdit:SetWidth(400)

    reviewEdit:DisableButton(true)
    reviewEdit:SetMaxLetters(90+45)
    reviewEdit:SetNumLines(6)
    reviewEdit:SetHeight(115)
    reviewEdit.editBox:SetFontObject(GameFontNormal)
    reviewEdit.editBox:SetTextColor(1, 1, 1, 0.75)
    reviewGroup:AddChild(reviewEdit)


    submitButton = AceGUI:Create("Button")
    submitButton:SetText(L["Submit Review"])
    submitButton:SetFullWidth(true)
    submitButton:SetHeight(40)
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


    -- Collect references for later access
    local prompt = {
        frame = frame,
        closeButton = closeButton,
        targetLabel = targetLabel,
        labelFontString = labelFontString,
        playedTime = playedTime,
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

    function prompt:SetPlayedTime(seconds)
        if seconds then
            playedLabel:Show()
            self.playedTime:SetText(SecondsToTime(seconds))
        else
            playedLabel:Hide()
            self.playedTime:SetText("")
        end
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
    prompt.starRating:SetRating(existingRating or 0)
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

    prompt:SetPlayedTime(clip.playedTime)


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